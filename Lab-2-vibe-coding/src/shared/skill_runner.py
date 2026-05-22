"""Sandboxed script runner for SkillsProvider.

Used by MAF SkillsProvider to execute `scripts/*.py` referenced from SKILL.md.
Hardening:
  - resolve absolute path; refuse if outside the skill's directory
  - whitelist python only
  - 60s timeout
  - capture stdout, drop stderr to logger
"""
from __future__ import annotations

import logging
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any

logger = logging.getLogger("workshop.skill_runner")

_TIMEOUT_SECONDS = 60


def run_local_skill_script(skill: Any, script: Any, args: list[str] | None = None) -> str:
    """Execute a skill script in a subprocess with safety checks.

    Args:
        skill: SkillsProvider's skill object with a `.path` attribute (skill directory).
        script: Script object with a `.path` attribute (absolute or relative to skill).
        args: command-line args to pass to the script.

    Returns:
        Captured stdout as text.
    """
    skill_dir = Path(skill.path).resolve()
    script_path = Path(script.path)
    if not script_path.is_absolute():
        script_path = (skill_dir / script_path).resolve()
    else:
        script_path = script_path.resolve()

    if skill_dir not in script_path.parents and script_path != skill_dir / script_path.name:
        raise PermissionError(f"Script {script_path} escapes skill dir {skill_dir}")

    if script_path.suffix != ".py":
        raise PermissionError(f"Only .py scripts are allowed; got {script_path}")

    cmd = [sys.executable, str(script_path), *(args or [])]
    logger.info("Running skill script: %s", shlex.join(cmd))

    try:
        proc = subprocess.run(  # noqa: S603 — args constructed above with safety checks
            cmd,
            capture_output=True,
            text=True,
            timeout=_TIMEOUT_SECONDS,
            cwd=str(skill_dir),
        )
    except subprocess.TimeoutExpired:
        logger.error("Skill script timed out after %ss: %s", _TIMEOUT_SECONDS, cmd)
        raise

    if proc.returncode != 0:
        logger.warning("Skill script exited %s; stderr=%s", proc.returncode, proc.stderr[:500])

    return proc.stdout
