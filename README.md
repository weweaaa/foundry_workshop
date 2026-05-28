# GitHub Copilot + Microsoft Foundry Hosted Agent · 90min Hands-on Workshop

> 用 5 个 Lab 在 90 分钟内搭出一个**可部署、可调用、可观测**的 Microsoft Foundry hosted agent，并用 GitHub Copilot 完成 persona / skill / tool 的业务迭代。
>
> 学员不创建 Azure 基础设施。讲师预先准备共享 Foundry account / project / model deployment / ACR；每位学员只部署名字带 `STUDENT_SUFFIX` 的 hosted agent。

## 语言版本

- 简体中文：[README.md](README.md)
- 繁體中文：[README.zh-TW.md](README.zh-TW.md)
- English: [README.en.md](README.en.md)

## 工作坊协作方式

这不是“照着文档复制命令”的 Lab。每一步都按同一个 coding-agent-driven 循环推进：

1. **Brief**：人类说明本步目标、业务边界和验收标准。
2. **Ask Copilot**：让 GitHub Copilot coding agent 先读相关文件，解释它看到的结构，再给出下一步。
3. **Run / Edit**：由 Copilot 帮你运行检查、生成骨架或修改文件；关键命令仍保留在文档里，便于人工审计。
4. **Verify**：用脚本、HTTP 调用、lint 或 dashboard 证明结果真的可用。
5. **Reflect**：让 Copilot 总结差异、失败原因和下一步，而不是只看“命令有没有跑完”。

人类负责意图、业务判断、安全边界和最终验收；Copilot 负责代码库探索、候选改动、命令执行、错误归因和验证总结。每个 Lab 都会给出明确的 handoff prompt 与 completion signal。

## 30 秒上手

**Windows（PowerShell）**

```powershell
git clone https://github.com/haxudev/foundry_workshop.git
cd foundry_workshop

Copy-Item .env.example .env
notepad .env      # 填讲师下发的 SP、Foundry endpoint/API key、ACR、STUDENT_SUFFIX

code Lab-0-setup\README.md
```

**macOS / Linux（bash）**

```bash
git clone https://github.com/haxudev/foundry_workshop.git
cd foundry_workshop

cp .env.example .env
${EDITOR:-nano} .env

code Lab-0-setup/README.md
```

关键约定：

- 仓库根目录只维护一份 `.env`；脚本会自动读取它。
- `chat-hosted.*`、`invoke-hosted.*`、`sanity-check.*` 走 Foundry `api-key` 或 OAuth2 REST，不需要 `az login`。
- `azd deploy` 仍需要 `azd auth login`，且 Lab 1 会把 `.env` 中的部署变量同步到当前 azd env。
- 不跑 `azd up` / `azd provision`：本工作坊没有学员侧 infra。

## 目录结构

```text
foundry_workshop/
├── README.md
├── .env.example                    # 复制成 .env，整个 workshop 共用
├── scripts/
│   ├── Windows/                    # PowerShell 7 / Windows PowerShell 5.1
│   ├── macOSLinux/                 # bash 3.2+，依赖 curl + jq
│   ├── chat-hosted/index.html      # 本地图形 chat UI
│   └── lint-persona.py
├── Lab-0-setup/                    # 工具、凭据、Copilot、azd auth
├── Lab-1-deploy-hosted-agent/      # 首次部署 research-agent 到共享 Foundry
├── Lab-2-vibe-coding/              # 本地业务 agent 主代码栈
│   ├── azure.yaml                  # azd deploy 入口，无 infra
│   ├── hooks/postdeploy-grant-roles.ps1
│   ├── personas/
│   ├── skills/
│   ├── tools/
│   ├── src/research_agent/
│   ├── tests/unit/
│   └── .github/                    # Copilot chatmodes / instructions / prompts
├── Lab-3-update-hosted-agent/      # 本地修改后重新发布 hosted agent
└── Lab-4-observability/            # 本地 HTML + Azure Monitor metrics
```

## 开场架构总览

一个能上生产的 agent 不是“写个 prompt + 接个模型”那么简单。这个 workshop 用一个轻量 harness 把它拆成可版本化、可部署、可观测的结构：

- **Soul / Persona**：角色边界、口吻、拒绝策略 → `Lab-2-vibe-coding/personas/*.md`
- **Skills**：完成任务的步骤说明书 → `Lab-2-vibe-coding/skills/<skill>/SKILL.md`
- **Tools**：调外部 API / 写状态的函数 → `Lab-2-vibe-coding/tools/*.py`
- **Runtime**：模型 + 容器 + 路由 → Microsoft Foundry Hosted Agent

```text
L3 应用层    Hosted Agent 容器 = Agent Framework app     ← Lab 2/3 主战场
			 ├── instructions ← personas/*.md
			 ├── context_providers=[SkillsProvider]
			 ├── tools=[client-side @tool]
			 └── client = FoundryChatClient

L2 模型与工具层  Foundry server-side tools + model deployment ← 讲师预部署
L1 共享基础设施  Foundry account / project / 模型 / ACR       ← 学员不动
```

默认场景是市场/竞品研究助手。想先跑通流程就直接使用默认 `research-agent`；想换业务，就在 Lab 2 中用 `/persona`、`/skill`、`/tool` 生成自己的三件套。

## 学完你能做到

1. 用 `azd deploy research-agent` 将 Agent Framework Python agent 发布到共享 Foundry project。
2. 用 GitHub Copilot（现场主路径是 VS Code Copilot Chat；终端 TUI 仅作可选路径）迭代 **Soul / Persona + Skills + Tools**。
3. 本地通过 `agentdev run` 调试业务 agent，再把修改发布到 hosted slot。
4. 用 `api-key` 调 hosted `/responses` endpoint，打开本地图形 chat UI 多轮对话。
5. 用 Lab 4 的本地 dashboard 查看 AgentResponses、tokens、tool calls、model latency 等 operational metrics。

## 时长结构（90 min）

| # | 环节 | 时长 | 出口产物 |
|---|------|------|----------|
| 0 | [开场 · 架构总览](#开场架构总览) | 5 min | 理解共享 Foundry + agent harness + 人机分工 |
| 1 | [Lab 0 · 环境 + 凭据 + Copilot](Lab-0-setup/README.md) | 10 min | readiness check 能说明“可进入 Lab 1” |
| 2 | [Lab 1 · 首次部署 hosted agent](Lab-1-deploy-hosted-agent/README.md) | 15 min | hosted endpoint 200 OK，Copilot 能解释部署链路 |
| 3 | Buffer | 5 min | — |
| 4 | [Lab 2 · Copilot vibe coding](Lab-2-vibe-coding/README.md) | 30 min | 本地 agent 返回业务 JSON，persona/skill/tool 有验收记录 |
| 5 | [Lab 3 · 更新 hosted agent](Lab-3-update-hosted-agent/README.md) | 10 min | hosted endpoint 返回更新后的业务 JSON，可解释 local vs hosted 差异 |
| 6 | [Lab 4 · 本地观测](Lab-4-observability/README.md) | 10 min | dashboard 显示自己的 metrics，可解释指标归属 |
| 7 | [Wrap-up](#wrap-up--下一步) | 5 min | 后续学习路径 |

## Copilot 双环境

现场主路径是 **VS Code GitHub Copilot**：它能自动读取 `Lab-2-vibe-coding/.github/` 里的 chatmode、instructions 和 prompts。终端里的 `copilot` TUI 只作为可选兜底，适合没有 VS Code Chat 的学员；不要把它写成旧的命令建议/解释工作流。

| 环境 | 入口 | 适合 |
|------|------|------|
| VS Code Copilot Chat（推荐） | Lab 0 安装 customization 后，打开 `Lab-2-vibe-coding/`，选择 `maf-agent` chatmode，使用 `/persona` `/skill` `/tool` `/deploy` | 生成/修改多文件 |
| Copilot TUI（可选） | 终端运行 `copilot`，进入 chat 后粘贴本 Lab 给出的 prompt 或模板内容 | 不能使用 VS Code Chat 时的兜底对话路径 |

两种环境都可以参考仓库根 `.agents/skills/` 下的官方 skill：

- `microsoft-foundry` — hosted agent 部署、调用、观测、评估、RBAC、配额
- `agent-framework-azure-ai-py` — Agent Framework Python SDK
- `azure-ai-projects-py` — Azure AI Projects SDK
- `skill-creator` — 创建 / 修订自定义 skill

## 卡住了怎么办

- 先跑对应自检：Windows `scripts\Windows\sanity-check.ps1`，macOS / Linux `scripts/macOSLinux/sanity-check.sh`。
- 部署失败只排 `azd deploy research-agent`，不要改共享 Foundry / ACR。
- 共享资源只操作自己的 `research-agent-<STUDENT_SUFFIX>`，不要删除或更新别人的 agent。

## 速查卡

### Copilot 提示语

每个 Lab 的起手模板：

```text
@workspace 我正在做 Lab <N>。请先阅读本 Lab README 和它引用的脚本/配置文件。
请按这 4 项回答：
1. 人类必须确认什么
2. 你可以帮我检查、运行或修改什么
3. 完成信号是什么
4. 失败时最小排查顺序是什么
```

让 Copilot 先读再行动：

```text
@workspace 先只读，不要修改文件。请阅读 #file:<path1> #file:<path2>，总结现状、风险和下一步验证命令。
等我确认后，再开始改动。
```

验证失败时：

```text
这是命令输出。请不要泛泛建议重装环境。
请基于当前 workshop 约束判断失败属于凭据、azd env、Foundry RBAC、agent runtime 还是代码逻辑；给出最小修复步骤和修完后应重跑的验证命令。
```

### PowerShell 常用提醒

- 服务主体登录 `azd` 时使用 `--client-secret=$Secret` 或 `--client-secret=$env:AZURE_CLIENT_SECRET`，避免 Windows PowerShell 5.1 把 secret 当参数前缀吞掉。
- 本 workshop 不运行 `azd up` / `azd provision` / `azd down`，只运行 `azd deploy research-agent`。
- 手动调 hosted agent 时优先用 `scripts/Windows/invoke-hosted.ps1`；它封装了 api-key、URL 构造和 response 索引。

### Foundry hosted agent API / metrics

- Hosted `/responses` URL：`<endpoint>/agents/<agent-name>/endpoint/protocols/openai/responses?api-version=2025-11-15-preview`
- 日常调用：`scripts/Windows/invoke-hosted.ps1 -Prompt "ping"` 或 `scripts/macOSLinux/invoke-hosted.sh --prompt "ping"`
- Lab 4 metrics 查询使用 Azure Monitor REST API，不走 Foundry api-key；脚本会用 SP 换 ARM token。
- `AgentResponses` 可按 `AgentId` 拆分；`AgentInputTokens`、`AgentOutputTokens`、`AgentToolCalls` 当前按 project 级别展示。

## Wrap-up · 下一步

今天完成的是一条 agent 迭代闭环：

```text
Soul / Persona + Skills + Tools
	↓ agentdev run 本地调试
Foundry Hosted Agent: research-agent-<STUDENT_SUFFIX>
	↓ operational metrics 进入 Azure Monitor
Lab 4 本地 dashboard
```

把这套方式带回团队时，可以继续沿用同一节奏：Brief → Ask Copilot → Inspect diff → Verify → Reflect。

下一步可以探索：

- **评估闭环**：把真实调用样本转成评估数据集，跑 batch eval，比较版本，再优化 prompt / persona。
- **多 agent 编排**：用 workflow 或 connected agents 把多个专职 agent 串起来。
- **MCP server**：把内部能力包装成 MCP，在 `agent.manifest.yaml` 里引用。
- **CI/CD**：在 PR 或 nightly 中跑 smoke eval / regression eval。

相关入口：

- [Microsoft Agent Framework](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview)
- [Microsoft Foundry Hosted Agents](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
- [`azd ai agent` 扩展](https://aka.ms/azdaiagent/docs)
- [Foundry Samples (Python)](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents)
- [GitHub Copilot in VS Code](https://aka.ms/vscode-copilot)
- [GitHub Copilot in the terminal](https://docs.github.com/copilot/github-copilot-in-the-cli)
