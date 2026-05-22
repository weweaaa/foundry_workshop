---
mode: agent
description: 生成一份 SKILL.md
---

参考 `#file:skills/market-research/SKILL.md` 与 `#file:.github/instructions/maf-skills.instructions.md`，
生成 `skills/${input:skillName}/SKILL.md`：

- 用途（一句话）：${input:purpose}
- 触发条件（2-4 条）：${input:triggers}
- 涉及的 @tool 函数：${input:tools}
- 涉及的其它 skills（如有）：${input:relatedSkills}

请输出严格按 instructions 的 frontmatter + 编号步骤的 SKILL.md。
末尾加"边界"小节说明何时不应使用本 skill。
