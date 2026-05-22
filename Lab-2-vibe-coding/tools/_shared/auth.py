"""Shared credential factory for tools that need to talk to internal APIs.

In hosted agent containers, prefer Managed Identity via DefaultAzureCredential.
"""
from __future__ import annotations

import logging
import os

from azure.identity.aio import DefaultAzureCredential

logger = logging.getLogger("workshop.tools.auth")

_cred: DefaultAzureCredential | None = None


def get_credential() -> DefaultAzureCredential:
    """Return a process-wide DefaultAzureCredential.

    Picks up:
      - hosted: Managed Identity
      - local dev: az / azd login
      - CI: env-based SP (AZURE_CLIENT_ID/AZURE_CLIENT_SECRET/AZURE_TENANT_ID)
    """
    global _cred
    if _cred is None:
        _cred = DefaultAzureCredential(
            exclude_interactive_browser_credential=os.environ.get("WORKSHOP_NONINTERACTIVE", "0") == "1",
        )
    return _cred


async def get_token(scope: str) -> str:
    cred = get_credential()
    token = await cred.get_token(scope)
    return token.token
