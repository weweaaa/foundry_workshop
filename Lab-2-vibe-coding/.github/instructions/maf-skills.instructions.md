---
applyTo: 'skills/**/SKILL.md'
---

You are writing an MAF **SKILL.md** — a process recipe the `SkillsProvider` injects into the agent's context.

## Required frontmatter

```yaml
---
name: <skill-name>
description: <一句话说明 this skill 在什么场景下被触发>
triggers:
  - <用户语言中的触发条件 1>
  - <2>
scripts:
  - <relative path to scripts/*.py, or empty list>
---
```

## Body conventions

- Use **numbered steps** (1, 2, 3 …). Each step has a single concrete action.
- Reference tools by exact `@tool` name (`web_search`, `web_fetch`, `report_builder`).
- Reference other skills by `name` if cross-skill flow is intended.
- End with a brief 边界 / pitfalls section.

## Anti-patterns

- Don't duplicate persona guardrails — link by `personas/shared/guardrails.md`.
- Don't hard-code arbitrary numbers — leave as parameters.
- Don't call external HTTP directly — that's a tool's job.
