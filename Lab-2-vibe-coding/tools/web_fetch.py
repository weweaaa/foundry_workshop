"""Web fetch tool — Jina Reader (r.jina.ai) 免费免 key 抓取 URL 正文为 markdown。

工作坊设计:
- Jina Reader 公开端点 https://r.jina.ai/<url> 返回去广告/去样板的 markdown
- 不需要 API key (免费档够 demo; 想加速可在 .env 设 JINA_API_KEY 自动用)
- 学员把 .env 填一次就行, 不需要单独申请抓取/解析服务
"""

import logging
import os
from datetime import date

import httpx
from agent_framework import tool as ai_function
from opentelemetry import trace
from pydantic import BaseModel, Field

logger = logging.getLogger("workshop.tools.web_fetch")
tracer = trace.get_tracer("workshop.tools.web_fetch")

_JINA_READER = "https://r.jina.ai/"


class FetchResult(BaseModel):
    url: str
    title: str = ""
    text: str = ""
    statusCode: int | None = None
    bytes: int = 0
    truncated: bool = False
    fetchedAt: str = ""
    cached: bool = Field(default=False, description="True 表示走了 mock / 错误兜底, 未真抓取")


# ---------------------------------------------------------------------------
# Mock fallback (kept tiny — used only when r.jina.ai is unreachable/forced)
# ---------------------------------------------------------------------------
_MOCK_PAGES: dict[str, FetchResult] = {
    "https://example-research.com/ai-notes-2025": FetchResult(
        url="https://example-research.com/ai-notes-2025",
        title="The State of AI Note-Taking Apps in 2025",
        text=(
            "Consumer AI note-taking is led by Notion AI (estimated 18M paid seats), "
            "Obsidian (1.5M Sync subscribers), and Mem (undisclosed). Notion grew ~24% YoY "
            "on AI-assist features rolled out in 2024."
        ),
        statusCode=200,
        bytes=256,
        cached=True,
    ),
}


def _parse_jina_markdown(md: str) -> tuple[str, str]:
    """Jina Reader markdown 形如:
        Title: <page title>
        URL Source: <resolved url>
        Published Time: <iso>
        Markdown Content:
        <... markdown body ...>
    抽出 title + body, 跳过所有头部元数据行直到 `Markdown Content:` 之后。
    """
    title = ""
    lines = md.splitlines()
    body_start = 0
    for i, line in enumerate(lines):
        if line.startswith("Title:") and not title:
            title = line[len("Title:"):].strip()
        if line.startswith("Markdown Content:"):
            body_start = i + 1
            break
    body = "\n".join(lines[body_start:]).strip()
    if not body:
        body = "\n".join(lines).strip()
    return title, body


@ai_function(
    name="web_fetch",
    description=(
        "用 Jina Reader 抓取一个公开 URL, 返回去广告/去样板的 markdown 正文。"
        "在 web_search 命中后用 result.url 喂给本工具拿细节。无需 API key。"
        "过长内容会被截断并设 truncated=true。"
    ),
)
async def web_fetch(url: str, max_chars: int = 4000, timeout: float = 15.0) -> FetchResult:
    """抓取 URL 正文。

    Args:
        url: 要抓的页面 URL, 必须 http(s)。
        max_chars: 正文最大保留字符, 默认 4000。
        timeout: 网络超时秒数, 默认 15。
    """
    today = date.today().isoformat()
    with tracer.start_as_current_span("web_fetch") as span:
        span.set_attribute("url", url)
        span.set_attribute("max_chars", max_chars)

        if not (url.startswith("http://") or url.startswith("https://")):
            raise ValueError(f"web_fetch only supports http(s); got: {url}")

        if os.environ.get("WORKSHOP_WEB_FETCH_FORCE_MOCK") == "1" or url in _MOCK_PAGES:
            r = _MOCK_PAGES.get(
                url,
                FetchResult(
                    url=url,
                    title="[mock]",
                    text=f"Mock placeholder for {url}.",
                    statusCode=200,
                    bytes=0,
                ),
            )
            r = r.model_copy(update={"fetchedAt": today, "cached": True})
            span.set_attribute("source", "mock")
            return r

        headers = {
            "Accept": "text/plain",
            "User-Agent": "foundry-workshop-research-agent/1.0",
        }
        # Optional Jina API key for higher rate limit / longer pages.
        jina_key = os.environ.get("JINA_API_KEY")
        if jina_key:
            headers["Authorization"] = f"Bearer {jina_key}"

        try:
            async with httpx.AsyncClient(timeout=timeout, headers=headers, follow_redirects=True) as client:
                resp = await client.get(_JINA_READER + url)
            text_raw = resp.text
            title, body = _parse_jina_markdown(text_raw)
            truncated = len(body) > max_chars
            span.set_attribute("source", "jina")
            span.set_attribute("statusCode", resp.status_code)
            return FetchResult(
                url=url,
                title=title,
                text=body[:max_chars],
                statusCode=resp.status_code,
                bytes=len(resp.content),
                truncated=truncated,
                fetchedAt=today,
            )
        except Exception as exc:
            logger.warning("web_fetch (jina) failed (%s); returning error stub.", exc)
            span.set_attribute("error", str(exc)[:200])
            return FetchResult(
                url=url,
                title="",
                text=f"[fetch error] {type(exc).__name__}: {exc}",
                statusCode=None,
                bytes=0,
                truncated=False,
                fetchedAt=today,
            )
