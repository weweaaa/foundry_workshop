# Workshop Utility Scripts

> 6 个学员或讲师在 Lab 0~4 里会用到的小工具。

| 脚本 | 用在哪个 Lab | 干什么 |
|------|------------|------|
| [`install-maf-copilot-skills.ps1`](./install-maf-copilot-skills.ps1) | Lab 0 | 启用 VS Code Copilot 的 chatmodes/instructions/prompts；打印 skill 入口 |
| [`sanity-check.ps1`](./sanity-check.ps1) | Lab 1 / Lab 3 | 验证学员 azd env / 共享 Foundry / 自己的 hosted agent / ACR 推送权限 |
| [`invoke-hosted.ps1`](./invoke-hosted.ps1) | Lab 1 / Lab 3 / Lab 4 | 拿 SP token + POST hosted agent + 打印响应；`-StatusOnly` 只看可达 |
| [`lint-persona.py`](./lint-persona.py) | Lab 2 | 校验 persona frontmatter / `{{include}}` 引用 / 必备 section |

> Lab 4 用的 `fetch-traces.ps1`（调 Foundry tracing data plane API 拉本人 agent 的 trace）放在 `workshop/Lab-4-observability/` 下，与 HTML 在一起。

## 用法示例

```powershell
# Lab 0
.\install-maf-copilot-skills.ps1

# Lab 1 / Lab 3 部署后自检
cd workshop\Lab-2-vibe-coding
..\scripts\sanity-check.ps1

# Lab 2 persona lint
..\scripts\lint-persona.py personas\research-agent.md

# Lab 3 hosted endpoint 调用
..\scripts\invoke-hosted.ps1 -AgentName "research-agent-$env:STUDENT_SUFFIX" -Prompt "ping"
```

## 跨平台说明

`*.ps1` 在 PowerShell 7 (`pwsh`) 与 Windows PowerShell 5.1 都能跑。脚本含中文，已用 UTF-8 BOM 保存以兼容 PS 5.1。Mac/Linux 学员请装 [PowerShell on Linux/macOS](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)。
