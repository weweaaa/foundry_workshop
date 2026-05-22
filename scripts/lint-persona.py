"""Persona linter — validate frontmatter, includes, and basic structure.

Usage:
    python scripts/lint-persona.py <persona-file.md> [...more]
Exits non-zero if any persona fails.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

_FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
_INCLUDE_RE = re.compile(r"\{\{include:\s*([^\}]+?)\s*\}\}")

REQUIRED_FRONTMATTER = ("version", "owner")
# 接受任一标识字段
IDENT_FIELDS = ("name", "agent")
# 接受英文或中文角色小节
ROLE_SECTION_PATTERNS = (
    re.compile(r"^#\s+Role\b", re.MULTILINE),
    re.compile(r"^#\s+角色", re.MULTILINE),
    re.compile(r"^##\s+角色", re.MULTILINE),
    re.compile(r"^##\s+Role\b", re.MULTILINE),
)


def _parse_frontmatter(text: str) -> dict[str, str] | None:
    m = _FM_RE.match(text)
    if not m:
        return None
    body = m.group(1)
    out: dict[str, str] = {}
    current_key: str | None = None
    for line in body.splitlines():
        if not line.strip():
            continue
        if line.startswith(("- ", "  ")):
            if current_key:
                out[current_key] = out.get(current_key, "") + line.strip() + ";"
            continue
        if ":" in line:
            key, _, val = line.partition(":")
            out[key.strip()] = val.strip()
            current_key = key.strip()
    return out


def lint(path: Path) -> tuple[bool, list[str]]:
    errors: list[str] = []
    if not path.exists():
        return False, [f"file not found: {path}"]

    text = path.read_text(encoding="utf-8")

    # Skip shared snippets (they have shared:true frontmatter)
    fm = _parse_frontmatter(text)
    if fm is None:
        errors.append("missing or malformed YAML frontmatter (--- ... ---)")
        return False, errors

    if fm.get("shared", "").lower() == "true":
        # shared snippet — different rules
        if not fm.get("version"):
            errors.append("shared snippet missing 'version' field")
        return (not errors), errors

    # Template files (*.template.md) are not deployed as-is; they get copied
    # into personas/ and edited. Skip include resolution.
    is_template = path.name.endswith(".template.md")

    # Normal agent persona checks
    for key in REQUIRED_FRONTMATTER:
        if not fm.get(key):
            errors.append(f"missing frontmatter field: {key}")
    if not any(fm.get(k) for k in IDENT_FIELDS):
        errors.append(f"missing identifier field (need one of {IDENT_FIELDS})")

    if not any(p.search(text) for p in ROLE_SECTION_PATTERNS):
        errors.append("missing role section (expect '# Role' or '## 角色')")

    if is_template:
        # Skip include resolution for templates.
        return (not errors), errors

    # Include references must resolve
    personas_root = path.parent
    # If the file is under personas/, climb to personas dir; otherwise relative to file dir
    if personas_root.name != "personas":
        # try walking up to find a personas dir
        for p in [path.parent, *path.parents]:
            if (p / "shared").is_dir() or p.name == "personas":
                personas_root = p
                break

    for include in _INCLUDE_RE.findall(text):
        target = (personas_root / include).resolve()
        if not target.exists():
            errors.append(f"unresolved include: {{{{include: {include}}}}} -> {target}")

    return (not errors), errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args(argv)

    failed = 0
    for s in args.paths:
        p = Path(s)
        ok, errs = lint(p)
        if ok:
            fm = _parse_frontmatter(p.read_text(encoding="utf-8")) or {}
            extends = fm.get("extends", "")
            version = fm.get("version", "?")
            ident = fm.get("name") or fm.get("agent") or p.stem
            tag = "template" if p.name.endswith(".template.md") else ""
            tag_str = f" [{tag}]" if tag else ""
            print(f"✅ persona {ident}{tag_str} OK · extends=[{extends}] · version={version}")
        else:
            failed += 1
            print(f"❌ persona {p}:")
            for e in errs:
                print(f"   - {e}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
