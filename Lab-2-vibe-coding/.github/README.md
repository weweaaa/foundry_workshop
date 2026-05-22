# Copilot MAF Skills

> 给学员的 VS Code Copilot 装上"市场调研 agent vibe coding"所需的上下文。这些文件随 workshop 仓库分发，自动被 Copilot 识别。

## 自动加载位置

VS Code Copilot Chat 在打开任意 workspace 时，会读取该 workspace 根目录下的：

- `.github/chatmodes/*.chatmode.md` — 自定义 chat mode（顶部下拉切换）
- `.github/instructions/*.instructions.md` — 按 `applyTo` glob 注入到匹配文件的 Copilot 上下文
- `.github/prompts/*.prompt.md` — `/<slug>` 斜杠命令

学员在 Lab 0 cd 到 `workshop/Lab-2-vibe-coding` 并 `code .`，本目录的所有文件即自动生效。

## 提供的 skill

| 文件 | 类型 | 触发方式 |
|------|------|---------|
| `chatmodes/maf-agent.chatmode.md` | chatmode | Copilot Chat 顶部下拉选择 "maf-agent" |
| `instructions/maf-tools.instructions.md` | instructions | 编辑 `tools/**/*.py` 时自动注入 |
| `instructions/maf-personas.instructions.md` | instructions | 编辑 `personas/**/*.md` 时自动注入 |
| `instructions/maf-skills.instructions.md` | instructions | 编辑 `skills/**/SKILL.md` 时自动注入 |
| `prompts/persona.prompt.md` | prompt | Chat 输入 `/persona` |
| `prompts/skill.prompt.md` | prompt | Chat 输入 `/skill` |
| `prompts/tool.prompt.md` | prompt | Chat 输入 `/tool` |
| `prompts/deploy.prompt.md` | prompt | Chat 输入 `/deploy` |

## 启用 VS Code 设置（如果默认未开）

VS Code 1.95+ 默认启用 chatmodes/prompts/instructions。如果没看到，运行：

```powershell
..\..\scripts\install-maf-copilot-skills.ps1
```

脚本会：

1. 检查 VS Code 与 Copilot 扩展版本；
2. 写 `.vscode/settings.json` 启用 `chat.promptFiles` / `chat.modeFiles` / `chat.instructionsFiles`；
3. 打开 VS Code 到当前目录。

## 改写默认场景

把这些 skill 文件改写成你自己的业务领域：

- chatmodes/maf-agent.chatmode.md 顶部"Default scenario"换成你的业务
- instructions/* 一般不改（约定层）
- prompts/*.prompt.md 改 input 字段与示例
