"""Foundry chat client factory.

Centralizes endpoint / deployment / credential wiring so each agent's main.py stays slim.
Uses ``agent_framework.foundry.FoundryChatClient`` (1.4 line) — the same client the official
Foundry hosted-agent samples use, paired with ``agent-framework-foundry-hosting`` as the
ASGI server.
"""
from __future__ import annotations

import os

from agent_framework.foundry import FoundryChatClient
from azure.identity.aio import DefaultAzureCredential


def build_chat_client() -> FoundryChatClient:
    """Build a ``FoundryChatClient`` from env vars.

    Required env:
        AZURE_AI_PROJECT_ENDPOINT       — full Foundry project endpoint
        AZURE_AI_MODEL_DEPLOYMENT_NAME  — model deployment name (e.g. gpt-5.5)
    """
    endpoint = os.environ.get("AZURE_AI_PROJECT_ENDPOINT")
    deployment = (
        os.environ.get("FOUNDRY_MODEL_DEPLOYMENT_NAME")
        or os.environ.get("AZURE_AI_MODEL_DEPLOYMENT_NAME")
    )
    if not endpoint:
        raise RuntimeError(
            "AZURE_AI_PROJECT_ENDPOINT is required. Set via "
            "`$env:AZURE_AI_PROJECT_ENDPOINT = azd env get-value AZURE_AI_PROJECT_ENDPOINT`."
        )
    if not deployment:
        raise RuntimeError(
            "FOUNDRY_MODEL_DEPLOYMENT_NAME (or AZURE_AI_MODEL_DEPLOYMENT_NAME) is required."
        )

    return FoundryChatClient(
        project_endpoint=endpoint,
        model=deployment,
        credential=DefaultAzureCredential(),
    )
