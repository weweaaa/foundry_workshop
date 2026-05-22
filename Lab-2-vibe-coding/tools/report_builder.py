"""Report builder tool — 把 sections + sources 组装成 persona 契约里的最终 JSON。"""

import logging
from datetime import date
from typing import Literal

from agent_framework import tool as ai_function
from opentelemetry import trace
from pydantic import BaseModel, Field, field_validator

logger = logging.getLogger("workshop.tools.report_builder")
tracer = trace.get_tracer("workshop.tools.report_builder")

Confidence = Literal["high", "medium", "low"]


class ReportSection(BaseModel):
    title: str
    body: str
    citations: list[int] = Field(default_factory=list, description="sources[].id 的引用列表")


class ReportSource(BaseModel):
    id: int = Field(ge=1)
    title: str
    url: str
    publishedAt: str | None = None
    accessedAt: str | None = None
    domain: str = ""
    kind: Literal["report", "news", "official", "wiki", "forum", "other"] = "other"

    @field_validator("url")
    @classmethod
    def _check_url(cls, v: str) -> str:
        if not (v.startswith("http://") or v.startswith("https://")):
            raise ValueError(f"source url must be http(s): {v}")
        return v


class ReportBody(BaseModel):
    summary: str
    sections: list[ReportSection]


class Report(BaseModel):
    topic: str
    subQuestions: list[str]
    report: ReportBody
    sources: list[ReportSource]
    confidence: Confidence
    caveats: list[str] = Field(default_factory=list)


def _validate_citations(sections: list[ReportSection], sources: list[ReportSource]) -> None:
    valid_ids = {s.id for s in sources}
    dup = {s.id for s in sources if sum(1 for x in sources if x.id == s.id) > 1}
    if dup:
        raise ValueError(f"sources 中存在重复 id: {sorted(dup)}")
    for sec in sections:
        bad = [c for c in sec.citations if c not in valid_ids]
        if bad:
            raise ValueError(
                f"section '{sec.title}' citations 引用了不存在的 source id: {bad}; "
                f"有效 id: {sorted(valid_ids)}"
            )


def _fill_accessed_at(sources: list[ReportSource]) -> list[ReportSource]:
    today = date.today().isoformat()
    out: list[ReportSource] = []
    for s in sources:
        if s.accessedAt:
            out.append(s)
            continue
        out.append(s.model_copy(update={"accessedAt": today}))
    return out


@ai_function(
    name="report_builder",
    description=(
        "把若干 sections + sources 组装成最终调研报告 JSON (符合 persona 输出契约)。"
        "**必须**在收集到 ≥3 个 sources 且覆盖 ≥2 个子问题后调用。"
        "工具会校验 citations 编号、源去重、URL 合法性；不通过会抛错让你修补。"
    ),
)
async def report_builder(
    topic: str,
    subQuestions: list[str],
    sections: list[ReportSection],
    sources: list[ReportSource],
    confidence: Confidence = "medium",
    caveats: list[str] | None = None,
    summary: str = "",
) -> Report:
    """组装最终报告。

    Args:
        topic: 用户问题简化后的主题。
        subQuestions: 子问题列表，对应 SKILL 的 step 1。
        sections: 报告章节，每节含 title / body / citations(sources id)。
        sources: 引用源数组，id 唯一、URL 合法。
        confidence: high|medium|low；按多源一致性给出。
        caveats: 注意事项 / 数据缺口 / 来源冲突。
        summary: 200 字以内 TL;DR；为空则用 sections 第一节首句兜底。
    """
    with tracer.start_as_current_span("report_builder") as span:
        span.set_attribute("topic", topic)
        span.set_attribute("section_count", len(sections))
        span.set_attribute("source_count", len(sources))

        _validate_citations(sections, sources)
        sources_filled = _fill_accessed_at(sources)

        final_summary = summary.strip()
        if not final_summary and sections:
            first = sections[0].body.strip()
            final_summary = first[:200]

        return Report(
            topic=topic,
            subQuestions=subQuestions,
            report=ReportBody(summary=final_summary, sections=sections),
            sources=sources_filled,
            confidence=confidence,
            caveats=caveats or [],
        )
