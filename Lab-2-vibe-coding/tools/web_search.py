"""Web search tool — DuckDuckGo HTML 端点免费查询，无需 API key。

工作坊设计:
- 不依赖任何付费 API; DuckDuckGo 公开的 HTML 端点 (html.duckduckgo.com) 即可
- 仍保留极简 mock 兜底, 学员断网/被 ddg 限流时不至于跑不动 demo
- 学员把 .env 填一次就行, 不需要单独申请 Bing/Google CSE key
"""

import logging
import os
import re
from datetime import date
from typing import Literal
from urllib.parse import parse_qs, unquote, urlparse

import httpx
from agent_framework import tool as ai_function
from opentelemetry import trace
from pydantic import BaseModel, Field

logger = logging.getLogger("workshop.tools.web_search")
tracer = trace.get_tracer("workshop.tools.web_search")

Provider = Literal["duckduckgo", "mock"]

_DDG_ENDPOINT = "https://html.duckduckgo.com/html/"


class SearchHit(BaseModel):
    title: str
    url: str
    snippet: str = ""
    domain: str = ""
    publishedAt: str | None = None


class WebSearchResult(BaseModel):
    query: str
    provider: Provider
    count: int
    results: list[SearchHit]
    cached: bool = Field(default=False, description="True 表示命中本地 mock，未走外网")


# ---------------------------------------------------------------------------
# Mock fallback (only fires when DDG fails / blocked / forced)
# ---------------------------------------------------------------------------
_MOCK_HITS: dict[str, list[SearchHit]] = {
    "ai notes app market": [
        SearchHit(
            title="The State of AI Note-Taking Apps in 2025",
            url="https://example-research.com/ai-notes-2025",
            snippet="Market overview of consumer AI note-taking apps: top 5 players, pricing, growth.",
            domain="example-research.com",
            publishedAt="2025-02-10",
        ),
        SearchHit(
            title="Notion AI vs Obsidian vs Mem — feature comparison",
            url="https://blog.example.com/notion-obsidian-mem",
            snippet="Side-by-side functional comparison updated for 2025.",
            domain="blog.example.com",
            publishedAt="2024-11-22",
        ),
    ],
    "新茶饮市场": [
        SearchHit(
            title="2024 新茶饮赛道白皮书",
            url="https://example-research.com/cn-tea-2024",
            snippet="中国新茶饮 2024 市场规模约 ¥3,547 亿元，同比增长 23%。",
            domain="example-research.com",
            publishedAt="2024-12-01",
        ),
    ],
}


def _normalize_domain(url: str) -> str:
    try:
        return urlparse(url).netloc.lower()
    except Exception:
        return ""


def _unwrap_ddg_redirect(href: str) -> str:
    """DDG HTML 端点的链接形如 /l/?uddg=<encoded url>; 解出真实 URL。"""
    if href.startswith("//duckduckgo.com/l/") or href.startswith("/l/"):
        try:
            qs = parse_qs(urlparse(href).query)
            if "uddg" in qs:
                return unquote(qs["uddg"][0])
        except Exception:
            pass
    return href


_RESULT_BLOCK_RE = re.compile(
    r'<a[^>]+class="result__a"[^>]+href="(?P<url>[^"]+)"[^>]*>(?P<title>.*?)</a>'
    r'(?:.*?<a[^>]+class="result__snippet"[^>]*>(?P<snippet>.*?)</a>)?',
    re.DOTALL,
)
_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"\s+")


def _strip_html(s: str) -> str:
    return _WS_RE.sub(" ", _TAG_RE.sub("", s)).strip()


async def _ddg_search(query: str, count: int, timeout: float = 10.0) -> list[SearchHit]:
    headers = {
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) foundry-workshop-research-agent/1.0",
        "Accept-Language": "en-US,en;q=0.9,zh;q=0.8",
    }
    async with httpx.AsyncClient(timeout=timeout, headers=headers, follow_redirects=True) as client:
        resp = await client.post(_DDG_ENDPOINT, data={"q": query})
        resp.raise_for_status()
        html = resp.text

    hits: list[SearchHit] = []
    for m in _RESULT_BLOCK_RE.finditer(html):
        url = _unwrap_ddg_redirect(m.group("url"))
        title = _strip_html(m.group("title") or "")
        snippet = _strip_html(m.group("snippet") or "")
        if not url or not title:
            continue
        hits.append(SearchHit(title=title, url=url, snippet=snippet, domain=_normalize_domain(url)))
        if len(hits) >= count:
            break
    return hits


def _mock_search(query: str, count: int) -> list[SearchHit]:
    q = query.lower().strip()
    for key, hits in _MOCK_HITS.items():
        if key.lower() in q or q in key.lower():
            return hits[:count]
    return [
        SearchHit(
            title=f"[mock] result for {query}",
            url=f"https://example.com/search?q={query}",
            snippet=f"Mock placeholder. Live DuckDuckGo search failed or was forced off. (today={date.today().isoformat()})",
            domain="example.com",
            publishedAt=date.today().isoformat(),
        )
    ][:count]


@ai_function(
    name="web_search",
    description=(
        "用 DuckDuckGo 公开端点搜索网页 (无需 API key)，返回 top N 条标题/URL/摘要。"
        "市场调研 agent 在不知道目标 URL 时**必须**先调用此工具。"
        "结果中的 url 接着喂给 web_fetch 取正文。"
    ),
)
async def web_search(query: str, count: int = 5) -> WebSearchResult:
    """检索公开网页。

    Args:
        query: 搜索词，中英文均可。要么具体 ("消费级 AI 笔记 应用 2025")，要么含品类+维度 ("新茶饮市场 份额")。
        count: 返回结果数, 1-10, 默认 5。
    """
    count = max(1, min(int(count or 5), 10))
    with tracer.start_as_current_span("web_search") as span:
        span.set_attribute("query", query)
        span.set_attribute("count", count)

        if os.environ.get("WORKSHOP_WEB_SEARCH_FORCE_MOCK") != "1":
            try:
                hits = await _ddg_search(query, count)
                if hits:
                    span.set_attribute("provider", "duckduckgo")
                    return WebSearchResult(
                        query=query, provider="duckduckgo", count=len(hits), results=hits
                    )
                logger.warning("DDG returned no hits for %r; falling back to mock.", query)
                span.set_attribute("fallback", "mock_empty")
            except Exception as exc:
                logger.warning("DDG search failed (%s); falling back to mock.", exc)
                span.set_attribute("fallback", str(exc)[:160])

        hits = _mock_search(query, count)
        span.set_attribute("provider", "mock")
        return WebSearchResult(
            query=query, provider="mock", count=len(hits), results=hits, cached=True
        )
