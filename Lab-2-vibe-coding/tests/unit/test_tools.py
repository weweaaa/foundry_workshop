"""Unit tests for web_search / web_fetch / report_builder."""
from __future__ import annotations

import asyncio
import os

import pytest

from tools.web_search import web_search, WebSearchResult
from tools.web_fetch import web_fetch, FetchResult
from tools.report_builder import (
    report_builder,
    Report,
    ReportSection,
    ReportSource,
)


def _run(coro):
    return asyncio.get_event_loop().run_until_complete(coro)


# ---------------------------------------------------------------------------
# web_search
# ---------------------------------------------------------------------------
def test_web_search_falls_back_to_mock_when_forced(monkeypatch):
    monkeypatch.setenv("WORKSHOP_WEB_SEARCH_FORCE_MOCK", "1")
    result: WebSearchResult = _run(web_search(query="ai notes app market", count=3))
    assert result.provider == "mock"
    assert result.cached is True
    assert 1 <= result.count <= 3
    assert all(h.url.startswith("http") for h in result.results)


def test_web_search_count_is_clamped(monkeypatch):
    monkeypatch.setenv("WORKSHOP_WEB_SEARCH_FORCE_MOCK", "1")
    big = _run(web_search(query="新茶饮市场", count=99))
    assert big.count <= 10
    small = _run(web_search(query="新茶饮市场", count=0))
    assert small.count >= 1


# ---------------------------------------------------------------------------
# web_fetch
# ---------------------------------------------------------------------------
def test_web_fetch_mock_url_returns_cached(monkeypatch):
    monkeypatch.setenv("WORKSHOP_WEB_FETCH_FORCE_MOCK", "1")
    r: FetchResult = _run(web_fetch(url="https://example-research.com/ai-notes-2025"))
    assert r.cached is True
    assert "Notion" in r.text or "AI" in r.text
    assert r.fetchedAt  # filled


def test_web_fetch_rejects_non_http():
    with pytest.raises(ValueError):
        _run(web_fetch(url="file:///etc/passwd"))


def test_web_fetch_unknown_url_force_mock_returns_placeholder(monkeypatch):
    monkeypatch.setenv("WORKSHOP_WEB_FETCH_FORCE_MOCK", "1")
    r: FetchResult = _run(web_fetch(url="https://nothing.invalid/page"))
    assert r.cached is True
    assert "Mock placeholder" in r.text


# ---------------------------------------------------------------------------
# report_builder
# ---------------------------------------------------------------------------
def _ok_sources() -> list[ReportSource]:
    return [
        ReportSource(id=1, title="A", url="https://a.example.com/x", kind="report"),
        ReportSource(id=2, title="B", url="https://b.example.com/y", kind="news"),
        ReportSource(id=3, title="C", url="https://c.example.com/z", kind="official"),
    ]


def test_report_builder_happy_path():
    sections = [
        ReportSection(title="市场玩家", body="头部 3 家(¹)(²)", citations=[1, 2]),
        ReportSection(title="增长", body="同比 23%(³)", citations=[3]),
    ]
    out: Report = _run(
        report_builder(
            topic="消费级 AI 笔记",
            subQuestions=["头部玩家", "增长"],
            sections=sections,
            sources=_ok_sources(),
            confidence="medium",
            caveats=["仅 2 个独立来源覆盖"],
        )
    )
    assert out.topic == "消费级 AI 笔记"
    assert out.confidence == "medium"
    assert len(out.sources) == 3
    assert all(s.accessedAt for s in out.sources)
    assert out.report.summary  # auto-filled from first section


def test_report_builder_rejects_unknown_citation():
    sections = [ReportSection(title="X", body="...", citations=[999])]
    with pytest.raises(ValueError):
        _run(
            report_builder(
                topic="t",
                subQuestions=["q"],
                sections=sections,
                sources=_ok_sources(),
            )
        )


def test_report_builder_rejects_duplicate_source_id():
    bad = [
        ReportSource(id=1, title="A", url="https://a.example.com/x"),
        ReportSource(id=1, title="dup", url="https://b.example.com/y"),
    ]
    with pytest.raises(ValueError):
        _run(
            report_builder(
                topic="t",
                subQuestions=["q"],
                sections=[ReportSection(title="X", body="...", citations=[1])],
                sources=bad,
            )
        )


def test_report_builder_rejects_non_http_url():
    with pytest.raises(ValueError):
        ReportSource(id=1, title="A", url="ftp://a.example.com/x")
