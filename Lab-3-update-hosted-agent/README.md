# Lab 3 · 把本地业务 agent 推到 Foundry hosted(25 min)

Lab 1 部了 Foundry 给的 placeholder agent;Lab 2 你在本地写好了 `src/research_agent/`(或你自己的业务 agent)。本 Lab 把本地代码增量推回 Foundry,**替换** Lab 1 的 placeholder。

## 3.1 目标

- 理解 `agent.yaml`(部署元数据)vs `agent.manifest.yaml`(运行时配置)的分工
- 用 `azd ai agent init -m src/<agent>/agent.manifest.yaml` 注册本地 agent 进 `azure.yaml`
- `azd deploy <agent>` 增量发布(不需要任何 infra)
- 用 hosted endpoint 验证业务

## 3.2 配合 Copilot

| 任务 | VS Code 走法 | Copilot CLI 走法 |
|------|------------|------|
| 生成 / 修 agent.yaml + manifest | `/deploy agentDir=… agentDeployName=…` | 复制 `Lab-2-vibe-coding/.github/prompts/deploy.prompt.md` 的模板 → `gh copilot suggest` |
| 部署失败排查 | `@workspace 这是 azd deploy 报错…(粘错误)` | `gh copilot explain "<错误>"` |
| Foundry 端的 RBAC / 配额 / 区域问题 | 关键词命中后自动加载 `.agents/skills/microsoft-foundry/` 的 `rbac/`、`quota/`、`models/` | 把对应子目录的 `.md` 拼到 prompt context |

## 3.3 两个 yaml 的分工

| 文件 | 回答什么问题 | 谁读 |
|------|------------|------|
| `agent.yaml` | "Foundry 怎么部署我?" kind / host / 语言 / 资源 / 环境变量 / scale | `azd ai agent init` / Foundry control plane(部署时) |
| `agent.manifest.yaml` | "我运行时要什么模型 + server-side tools?" | Foundry control plane(运行时) |

研究 agent 用例:`src/research_agent/agent.yaml` + `src/research_agent/agent.manifest.yaml` 都已经写好。

## 3.4 用 Copilot 检查 / 生成 yaml

VS Code:

```
/deploy agentDir=research_agent agentDeployName=research-agent-${STUDENT_SUFFIX}
```

或自带业务:

```
/deploy agentDir=my_agent agentDeployName=invoice-explainer-${STUDENT_SUFFIX}
```

Copilot 会按 `.github/prompts/deploy.prompt.md` 重写两个 yaml,并保证:

- `kind: hosted`,`host: azure.ai.agent`,`docker.remoteBuild: true`
- 资源 cpu 1 / memory 2Gi,scale 1-3
- env: `AZURE_AI_PROJECT_ENDPOINT / AZURE_AI_MODEL_DEPLOYMENT_NAME / AGENT_NAME / STUDENT_SUFFIX`
- `model: ${AZURE_AI_MODEL_DEPLOYMENT_NAME}`(不写死,引用预部署 deployment)

Copilot CLI:

```powershell
$tpl = Get-Content Lab-2-vibe-coding\.github\prompts\deploy.prompt.md -Raw
$prompt = "$tpl`n`n参数: agentDir=research_agent, agentDeployName=research-agent-`${STUDENT_SUFFIX}"
gh copilot suggest $prompt
```

## 3.5 注册进 azd(覆盖 Lab 1 placeholder)

```powershell
# 替换 azure.yaml services 中的 placeholder
azd ai agent init -m src\research_agent\agent.manifest.yaml
```

如果 Lab 1 注入的 `agent-framework-agent-basic-responses` 还在 `azure.yaml.services` 里,手动删掉它,只留 `research-agent` 这一段。

## 3.6 部署

```powershell
azd env set AGENT_NAME "research-agent-$env:STUDENT_SUFFIX"
azd deploy research-agent
```

10 分钟内完成。等待时讲师讲解:

- **Dockerfile** 必须 `--platform=linux/amd64` —— 已经放在 `src/research_agent/Dockerfile`
- **server-side tool 声明**:`agent.manifest.yaml.tools[]` 当前只开了 `code_interpreter`;要加 `grounding_with_bing_search` 请取消注释并填 connection id
- **环境变量自动注入**:`${...}` 由 azd env 在部署时替换
- **学员后缀**:同一 project 里多个学员的 hosted agent 共存 —— 靠后缀区分

## 3.7 验证 hosted endpoint

**🖥️  图形化多轮对话 (推荐)**

```powershell
..\scripts\chat-hosted.ps1
```

在浏览器里跟自己的 agent 多轮聊天 (详见 Lab 1 §1.7). 业务问题示例:

- "帮我研究'消费级 AI 笔记应用'品类, 2025 重点对比 5 家"
- "刚才说的第二家, 找两个负面评价"   ← 多轮上下文应该 hit
- "X 公司值不值得投资?" ← 应该触发 guardrail 拒答

**💻  命令行单 prompt (CI / 脚本)**

```powershell
..\scripts\invoke-hosted.ps1 `
    -AgentName "research-agent-$env:STUDENT_SUFFIX" `
    -Prompt "帮我研究'消费级 AI 笔记应用'品类,2025 重点对比 5 家"
```

应返回与 Lab 2 本地版本一致的业务 JSON(包含 `report` / `sources` / `confidence`)。trace 会进 Foundry 内置存储,下一 Lab 拉。

## 3.8 看 agent 状态

```powershell
..\scripts\invoke-hosted.ps1 -StatusOnly -AgentName "research-agent-$env:STUDENT_SUFFIX"
# status=Reachable, http=200, agent=research-agent-stuNN
```

## 3.9 出口检查点

✅ `azure.yaml` 只剩 `research-agent`(或你的业务 agent 名)
✅ `azd deploy` 完成,无错
✅ `invoke-hosted.ps1` 返回业务 JSON
✅ `sanity-check.ps1` 全 ✅

## 3.10 故障速查

| 现象 | 处理 |
|------|------|
| `azd deploy` ACR push 慢 | 第一次推 base image;后续会复用 layer |
| hosted 调用 401 | `az account get-access-token --resource https://ai.azure.com` 重拿;脚本会自动重试一次 |
| 模型说找不到 instructions | `agent.manifest.yaml.instructions.file` 路径相对 manifest 自己;确认指向 `../../personas/<agent>.md` |
| 旧版本 placeholder 还在 | 不影响调用,但碍眼;在 Foundry MCP 工具或 Portal 上手动删(讲师代办) |
| `azd up` 失败 | 你跑错了:本工作坊只有 `azd deploy`,没有 infra |
| `Insufficient quota` / `Capacity not available` | 共享模型 deployment 配额被占满;问 `.agents/skills/microsoft-foundry/quota/` 或联系讲师 |

## 3.11 加分挑战

1. 把 `agent.manifest.yaml` 里的 `grounding_with_bing_search` 取消注释(讲师如果已在 project 上 connected Bing 资源)。
2. 改 `agent.yaml.scale.minReplicas: 0` 体验冷启动(p95 跳到 5s+),再改回 1。
3. 用 Foundry MCP / `azd ai agent update` 手动升级 instructions,看是否自动生成新版本(`version: 2`)。

> 更深入的部署 / 升级 / 版本管理流程见 `.agents/skills/microsoft-foundry/foundry-agent/deploy/deploy.md`。

→ [Lab 4 · 本地可观测性](../Lab-4-observability/HANDBOOK.md)
