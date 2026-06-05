# Lab 3 · 把本地业务 agent 更新到 Foundry hosted（10 min）

Lab 2 中你已经在本地调试了 `src/research_agent/`，或创建了自己的业务 agent。本 Lab 将修改后的代码重新发布到共享 Foundry project。

## 3.1 目标

- 理解 `agent.yaml.tpl` 与 `agent.manifest.yaml.tpl` 的分工。
- 确认 `azure.yaml` 指向要发布的 agent。
- 用 `azd deploy research-agent` 增量发布。
- 用 hosted endpoint 验证业务输出。

## 3.2 Agent-driven 发布方式

Lab 3 的核心不是“再跑一次 deploy”，而是把 Lab 2 的本地产物安全发布到 hosted slot。先让 Copilot 做一次只读 release review：

```text
@workspace 我正在做 Lab 3。请阅读 #file:Lab-2-vibe-coding/azure.yaml、#file:Lab-2-vibe-coding/src/research_agent/agent.yaml.tpl、#file:Lab-2-vibe-coding/src/research_agent/agent.manifest.yaml.tpl、#file:Lab-2-vibe-coding/src/research_agent/main.py 和 #file:Lab-2-vibe-coding/personas/research-agent.md。
请检查 local artifact 到 hosted agent 的发布链路，指出部署前必须确认的 5 件事；不要修改文件。
```

| 人类负责 | Copilot coding agent 负责 | 完成信号 |
|----------|---------------------------|----------|
| 确认 Lab 2 的业务行为已经验收，允许覆盖自己的 hosted agent | 检查 yaml alignment、解释 deploy 影响、归因 hosted 调用错误 | hosted `/responses` 返回更新后的业务 JSON，guardrail 仍生效 |

## 3.3 两个 yaml 的分工

| 文件 | 解决什么问题 | 主要字段 |
|------|--------------|----------|
| `src/research_agent/agent.yaml.tpl` | Foundry 如何托管容器；部署前渲染成 `agent.yaml` | `kind: hosted`、`protocols`、`resources`、`environment_variables` |
| `src/research_agent/agent.manifest.yaml.tpl` | agent 运行时用什么模型和 server-side tools；部署前渲染成 `agent.manifest.yaml` | `model`、`instructions.file`、`tools` |
| `azure.yaml` | azd 如何构建并发布 service | `host: azure.ai.agent`、`docker.remoteBuild: true`、postdeploy hook |

默认 `research-agent` 已经配置好。自带业务时，可用 Copilot `/deploy` 生成新目录的两个 yaml，再把 `azure.yaml.services` 指向新 service。

## 3.4 配合 Copilot 检查部署配置

VS Code：

```text
@workspace 检查 #file:azure.yaml #file:src/research_agent/agent.yaml.tpl #file:src/research_agent/agent.manifest.yaml.tpl 是否适合部署到共享 Foundry project；不要创建 infra，不要本地 Docker build。
```

Copilot TUI（可选）：启动 `copilot` 进入 chat 后粘贴下面这段：

```text
检查 Lab-2-vibe-coding 的 azure.yaml、src/research_agent/agent.yaml.tpl、src/research_agent/agent.manifest.yaml.tpl。
要求: host=azure.ai.agent, docker.remoteBuild=true, model 用 ${AZURE_AI_MODEL_DEPLOYMENT_NAME}, 不包含 infra。
```

让 Copilot 输出时要求它按这个格式：

```text
请按 OK / Risk / Fix 三列列出检查结果。Risk 只包含会影响 azd deploy 或 hosted runtime 的问题。
```

## 3.5 发布

从 `Lab-2-vibe-coding` 目录执行。

**Windows（PowerShell）**

```powershell
. ..\scripts\Windows\load-env.ps1
azd env set AGENT_NAME "research-agent-$env:STUDENT_SUFFIX"
azd deploy research-agent
```

**macOS / Linux（bash）**

```bash
source ../scripts/macOSLinux/load-env.sh
azd env set AGENT_NAME "research-agent-${STUDENT_SUFFIX}"
azd deploy research-agent
```

部署完成后，postdeploy hook 会再次为最新版本的 runtime identities 补齐 `AcrPull` 和 `Azure AI User`。这是每个新版本都需要的步骤，脚本是幂等的。

## 3.6 验证 hosted endpoint

### 图形化多轮对话（推荐）

**Windows（PowerShell）**

```powershell
..\scripts\Windows\chat-hosted.ps1
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/chat-hosted.sh
```

示例问题：

- `帮我研究'消费级 AI 笔记应用'品类，2025 重点对比 5 家`
- `刚才说的第二家，找两个负面评价`
- `X 公司值不值得投资？`（应触发 guardrail 拒答）

### 命令行验证

**Windows（PowerShell）**

```powershell
..\scripts\Windows\invoke-hosted.ps1 `
  -Prompt "帮我研究'消费级 AI 笔记应用'品类，2025 重点对比 5 家"
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/invoke-hosted.sh \
  --prompt "帮我研究《消费级 AI 笔记应用》品类，2025 重点对比 5 家"
```

应返回与本地版本一致的业务 JSON。

### Local vs hosted 对比

如果 Lab 2 的本地服务仍在运行，可以让 Copilot 帮你设计同一个 prompt 的对比：

```text
我想比较本地 http://localhost:8087/responses 和 hosted invoke-hosted 的输出。请给我一组最小验证 prompt：一个成功业务问题、一个多轮上下文问题、一个 guardrail 拒答问题，并说明预期差异。
```

对比时不要求逐字一致；重点看字段结构、引用策略、拒答边界和 tool 使用意图是否一致。

## 3.7 状态检查

**Windows（PowerShell）**

```powershell
..\scripts\Windows\invoke-hosted.ps1 -StatusOnly
..\scripts\Windows\sanity-check.ps1
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/invoke-hosted.sh --status-only
../scripts/macOSLinux/sanity-check.sh
```

## 3.8 出口检查点

- `azd deploy research-agent` 完成无错。
- hosted `/responses` 返回更新后的业务 JSON。
- `sanity-check.*` 全部关键项通过。
- Lab 4 前至少调用几次 hosted agent，让 Monitor metrics 有数据。
- Copilot 能解释本次发布是否只是业务代码更新，还是也改变了 model、server-side tools 或资源配置。

## 3.9 故障速查

| 现象 | 处理 |
|------|------|
| `azd deploy` 提示变量缺失 | 回 Lab 1 §1.4 同步 azd env，尤其 `AZURE_AI_PROJECT_ID` |
| ACR remote build 慢 | 首次构建慢，后续 layer 会复用 |
| hosted 调用 401 | 检查 `FOUNDRY_API_KEY` 与 project endpoint |
| hosted 调用 server error | 把错误 body 贴给 Copilot；先等 postdeploy RBAC 传播 1-2 分钟，必要时重跑 `azd deploy research-agent` |
| instructions 找不到 | `agent.manifest.yaml.instructions.file` 路径相对 manifest 自身，默认应为 `../../personas/research-agent.md` |
| quota / capacity 错误 | 共享 model deployment 被占满，稍后重试或联系讲师 |

## 3.10 加分挑战

1. 在 `agent.manifest.yaml` 中启用讲师已配置好的 server-side tool（例如 Bing grounding）。
2. 改 tool 的 mock/live 行为并重新部署，比较 hosted 输出差异。
3. 用 Copilot 生成一版自带业务 agent，再把 `azure.yaml` 指向新 service 发布。

→ [Lab 4 · 本地可观测性](../Lab-4-observability/README.md)
