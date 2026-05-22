---
applyTo: 'personas/**/*.md'
---

You are writing a **persona** (Soul) for an MAF Foundry hosted agent.

## Frontmatter (required)

```yaml
---
name: <agent-name>
version: <semver>
owner: <team@contoso.com>
extends: shared/guardrails.md      # if extending shared guardrails
---
```

## Body sections

1. **角色** — who this agent is, scope, what it does not do.
2. **推理风格** — calling pattern (plan first, multi-source, hedge when uncertain).
3. **工具调用规范** — table mapping when to call each tool.
4. **输出契约** — JSON schema the agent must return.
5. **越权与边界** — defer to `shared/guardrails.md`; add agent-specific refusals.
6. **示例** — at least 1 user turn → desired plan/output.
7. **自检清单** — markdown checkboxes for the model to self-audit before responding.

## Style

- Chinese instructions, English code fences.
- Be specific about citation requirements when the agent outputs facts.
- Avoid "可能"/"也许" weasel words — be definite.

## Include directive

Use `{{include: shared/guardrails.md}}` once at the top of body to inline the shared guardrails. The persona loader handles include expansion automatically.
