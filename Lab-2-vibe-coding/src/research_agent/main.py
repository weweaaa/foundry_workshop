"""ResearchAgent — market/competitive research using web_search + web_fetch + report_builder.

Local dev:
    $env:AZURE_AI_PROJECT_ENDPOINT     = azd env get-value AZURE_AI_PROJECT_ENDPOINT
    $env:AZURE_AI_MODEL_DEPLOYMENT_NAME = azd env get-value AZURE_AI_MODEL_DEPLOYMENT_NAME
    python -m src.research_agent.main
"""
from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

from agent_framework import Agent, FileSkillsSource, SkillsProvider

# Repo root must be importable for `tools.*` / `src.shared.*`.
_REPO = Path(__file__).resolve().parents[2]
if str(_REPO) not in sys.path:
    sys.path.insert(0, str(_REPO))

from src.shared.client_factory import build_chat_client  # noqa: E402
from src.shared.persona import load_persona  # noqa: E402
from tools.web_search import web_search  # noqa: E402
from tools.web_fetch import web_fetch  # noqa: E402
from tools.report_builder import report_builder  # noqa: E402


logging.basicConfig(level=logging.INFO)


def build_agent() -> Agent:
    skills_provider = SkillsProvider(FileSkillsSource(skill_paths=[_REPO / "skills"]))
    return Agent(
        build_chat_client(),
        instructions=load_persona("research-agent.md"),
        name=os.environ.get("AGENT_NAME", "research-agent"),
        context_providers=[skills_provider],
        tools=[web_search, web_fetch, report_builder],
    )


agent = build_agent()


if __name__ == "__main__":
    # Foundry hosted runtime probes /readiness and /responses on port 8088 (or DEFAULT_AD_PORT).
    from agent_framework_foundry_hosting import ResponsesHostServer  # type: ignore

    server = ResponsesHostServer(agent)
    server.run()
