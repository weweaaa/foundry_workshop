---
mode: agent
description: 生成或更新一个 MAF persona (Soul)
---

参考 `#file:personas/shared/guardrails.md` 与 `#file:personas/research-agent.md`，
为我生成一个新的 persona 文件 `personas/${input:agentName}.md`：

- 角色：${input:role}
- 用户的关键边界：${input:boundaries}
- 工具：${input:tools}
- 输出契约（JSON schema 简述）：${input:contract}

要求：
1. 严格遵守 `#file:.github/instructions/maf-personas.instructions.md` 的 frontmatter 与章节顺序。
2. body 顶部用 `{{include: shared/guardrails.md}}` inline 共享 guardrails。
3. 输出契约必须给出 minimal viable JSON schema（字段名 + 类型 + 简短说明）。
4. 至少 1 个 user-turn 示例 + 1 段计划响应。
5. 末尾给出 5 项以上自检清单（checkbox）。

生成后再执行 `python ..\scripts\lint-persona.py personas\${input:agentName}.md`
(macOS / Linux: `python3 ../scripts/lint-persona.py personas/${input:agentName}.md`)
确认通过。
