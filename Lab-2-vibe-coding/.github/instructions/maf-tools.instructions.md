---
applyTo: 'tools/**/*.py'
---

You are writing a client-side **MAF `@tool` function** for the workshop research agent.

## Mandatory structure

```python
"""<one-line description in Chinese>."""
from __future__ import annotations

import logging
import os
from typing import Literal

import httpx
from agent_framework import tool
from opentelemetry import trace
from pydantic import BaseModel, Field

logger = logging.getLogger("workshop.tools.<name>")
tracer = trace.get_tracer("workshop.tools.<name>")


class <ToolName>Result(BaseModel):
    # pydantic typed output; fields use camelCase OR snake_case but consistent.
    ...


@tool(
    name="<tool_name>",
    description=(
        "<中文：何时调用、输入要点、输出含义>"
    ),
)
async def <tool_name>(...) -> <ToolName>Result:
    """<docstring in English for IDE>.

    Args:
        ...: <中文参数解释>
    """
    with tracer.start_as_current_span("<tool_name>") as span:
        span.set_attribute("...", ...)
        # 1. live call branch
        if os.environ.get("<API_ENV_KEY>"):
            try:
                ...
                span.set_attribute("source", "live")
                return result
            except Exception as exc:
                logger.warning("Live call failed (%s); falling back to mock.", exc)
                span.set_attribute("fallback", "mock")
        # 2. mock fallback
        ...
        return result
```

## Hard rules

- Always async (`async def`).
- Always pydantic input/output models, **never** raw dict.
- Always include a mock branch — `WORKSHOP_<tool>_FORCE_MOCK=1` should also force-mock if relevant.
- Set OTel attributes for: provider/source, cached, key parameters (avoid PII).
- Description (Chinese) tells the model *when* to call this tool — be specific, not generic.
- Don't call other `@tool` functions from inside; the agent orchestrates.

## Don't

- Don't import `agent_framework.foundry.FoundryChatClient` here (that's `src/shared/client_factory.py`'s job).
- Don't write to disk except via temp dirs.
- Don't log secrets / Bearer tokens.
