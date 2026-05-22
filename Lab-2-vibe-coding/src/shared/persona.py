"""Persona loader with {{include: ...}} expansion.

Personas live under <repo>/Lab-2-vibe-coding/personas/.
Usage:
    text = load_persona("billing-agent.md")
"""
from __future__ import annotations

import re
from functools import lru_cache
from pathlib import Path

_INCLUDE_RE = re.compile(r"\{\{include:\s*([^\}]+?)\s*\}\}")
_PERSONAS_ROOT = Path(__file__).resolve().parents[2] / "personas"


@lru_cache(maxsize=64)
def load_persona(name: str) -> str:
    """Load a persona markdown, expanding `{{include: <relpath>}}` directives.

    Args:
        name: filename or relpath under personas/ (e.g., 'billing-agent.md'
              or 'shared/guardrails.md').
    """
    path = (_PERSONAS_ROOT / name).resolve()
    if not _PERSONAS_ROOT in path.parents and path != _PERSONAS_ROOT / name:
        raise ValueError(f"Persona path escapes personas root: {name}")
    if not path.exists():
        raise FileNotFoundError(f"Persona not found: {path}")

    text = path.read_text(encoding="utf-8")

    def _sub(match: re.Match[str]) -> str:
        included = match.group(1).strip()
        return load_persona(included)

    return _INCLUDE_RE.sub(_sub, text)
