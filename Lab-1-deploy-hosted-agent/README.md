# Lab 1 · 首次部署你的 Foundry hosted agent（15 min）

## 1.1 目标

- 理解当前仓库为什么只有 `azd deploy`，没有 `azd up` / infra。
- 将 `.env` 中的部署变量同步到 Lab-2 的 azd env。
- 用 `azd deploy research-agent` 把参考实现发布到共享 Foundry project。
- 用本地图形 chat 或命令行脚本验证 hosted `/responses` endpoint。

> Lab 1 先部署仓库自带的 `research-agent`。Lab 2 会在本地修改业务逻辑，Lab 3 再把修改后的版本重新发布。

## 1.2 Agent-driven 跑法

把 Lab 1 当成一次可审计的发布，而不是一串 `azd` 命令。先让 Copilot 读部署入口并解释它将验证什么：

```text
@workspace 我正在做 Lab 1。请阅读 #file:Lab-2-vibe-coding/azure.yaml、#file:Lab-2-vibe-coding/src/research_agent/agent.yaml、#file:Lab-2-vibe-coding/src/research_agent/agent.manifest.yaml 和 #file:Lab-2-vibe-coding/hooks/postdeploy-grant-roles.ps1。
请先解释部署会做什么、为什么不能运行 azd up、以及部署后的完成信号。
```

| 人类负责 | Copilot coding agent 负责 | 完成信号 |
|----------|---------------------------|----------|
| 确认 `.env` 来自讲师、同意部署自己的 `research-agent-<STUDENT_SUFFIX>` | 检查 azd env 是否缺字段、解释 `azure.yaml`、归因 deploy / invoke 错误 | `azd deploy research-agent` 成功，`invoke-hosted.* -Prompt ping` 返回 completed |

## 1.3 配合 Copilot

| 任务 | VS Code 走法（主路径） | Copilot TUI 走法（可选） |
|------|--------------|------------------|
| 解释 `azure.yaml` | `@workspace 解释 #file:azure.yaml 的 services.research-agent` | 运行 `copilot` 进入 chat，粘贴 `azure.yaml` 相关片段并问同样问题 |
| 看懂部署元数据 | `#file:src/research_agent/agent.yaml #file:src/research_agent/agent.manifest.yaml explain the difference` | 粘贴两个 yaml 的相关内容，让 TUI chat 对比分工 |
| 部署失败排查 | 粘贴 `azd deploy` 错误并要求只分析本 workshop 路径 | 粘贴错误输出，让 TUI chat 只围绕本 workshop 约束排查 |

## 1.4 初始化 azd env 并同步变量

从仓库根目录开始。

**Windows（PowerShell）**

```powershell
. .\scripts\Windows\load-env.ps1
cd Lab-2-vibe-coding
azd init -e dev --no-prompt

azd env set AZURE_SUBSCRIPTION_ID $env:AZURE_SUBSCRIPTION_ID
azd env set AZURE_LOCATION $env:AZURE_LOCATION
azd env set AZURE_AI_PROJECT_ENDPOINT $env:AZURE_AI_PROJECT_ENDPOINT
azd env set AZURE_AI_PROJECT_ID $env:AZURE_AI_PROJECT_ID
azd env set AZURE_AI_MODEL_DEPLOYMENT_NAME $env:AZURE_AI_MODEL_DEPLOYMENT_NAME
azd env set AZURE_CONTAINER_REGISTRY_NAME $env:AZURE_CONTAINER_REGISTRY_NAME
azd env set AZURE_CONTAINER_REGISTRY_ENDPOINT $env:AZURE_CONTAINER_REGISTRY_ENDPOINT
azd env set STUDENT_SUFFIX $env:STUDENT_SUFFIX
azd env set AGENT_NAME "research-agent-$env:STUDENT_SUFFIX"
```

**macOS / Linux（bash）**

```bash
source scripts/macOSLinux/load-env.sh
cd Lab-2-vibe-coding
azd init -e dev --no-prompt

azd env set AZURE_SUBSCRIPTION_ID "$AZURE_SUBSCRIPTION_ID"
azd env set AZURE_LOCATION "$AZURE_LOCATION"
azd env set AZURE_AI_PROJECT_ENDPOINT "$AZURE_AI_PROJECT_ENDPOINT"
azd env set AZURE_AI_PROJECT_ID "$AZURE_AI_PROJECT_ID"
azd env set AZURE_AI_MODEL_DEPLOYMENT_NAME "$AZURE_AI_MODEL_DEPLOYMENT_NAME"
azd env set AZURE_CONTAINER_REGISTRY_NAME "$AZURE_CONTAINER_REGISTRY_NAME"
azd env set AZURE_CONTAINER_REGISTRY_ENDPOINT "$AZURE_CONTAINER_REGISTRY_ENDPOINT"
azd env set STUDENT_SUFFIX "$STUDENT_SUFFIX"
azd env set AGENT_NAME "research-agent-${STUDENT_SUFFIX}"
```

> `azd env` 只保存部署需要的非交互变量；脚本和 postdeploy hook 仍会读取仓库根 `.env`。

同步完成后可以让 Copilot 帮你做一次只读核对：

```text
我已经运行 Lab 1 的 azd env set。请告诉我还应该用哪些 azd env get-value 命令核对变量，不要修改任何文件。
```

## 1.5 看懂 Lab-2 的部署入口

在 `Lab-2-vibe-coding/azure.yaml` 里，核心信息只有一个 service：

```yaml
services:
  research-agent:
    project: src/research_agent
    host: azure.ai.agent
    language: docker
    docker:
      remoteBuild: true
```

要点：

- `remoteBuild: true` 表示镜像由 ACR remote build 完成，不要求学员本机安装 Docker。
- 没有 `infra:`，因为共享 Foundry / ACR 已由讲师创建。
- `hooks.postdeploy` 会自动给 Foundry 为该 agent 版本创建的 managed identities 授 `AcrPull` 和 `Azure AI User`。

## 1.6 部署

```powershell
azd deploy research-agent
```

部署会做三件事：

1. 用 ACR remote build 构建并推送镜像。
2. 在共享 Foundry project 中 create/update `research-agent-<STUDENT_SUFFIX>`。
3. 执行 postdeploy hook，补齐该版本 runtime identity 的拉镜像和调模型权限。

> 不要执行 `azd up`。本工作坊没有学员侧 infra，`azd up` / `azd provision` 不是正确路径。

## 1.7 验证 hosted endpoint

### 图形化聊天（推荐）

**Windows（PowerShell）**

```powershell
..\scripts\Windows\chat-hosted.ps1
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/chat-hosted.sh
```

脚本会读取根目录 `.env` 里的 `FOUNDRY_API_KEY`、project endpoint 和 agent name，打开本地 HTML chat UI。凭据只放在本地 URL hash 中，不会发给第三方。

### 命令行验证

**Windows（PowerShell）**

```powershell
..\scripts\Windows\invoke-hosted.ps1 -Prompt "ping"
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/invoke-hosted.sh --prompt "ping"
```

返回 JSON 中 `status` 为 `completed`，且有文本输出即通过。

让 Copilot 根据验证结果做一次发布复盘：

```text
这是 invoke-hosted 的输出。请判断 Lab 1 是否完成，并用 3 条说明 hosted agent、FOUNDRY_API_KEY、postdeploy RBAC 分别是否正常。
```

## 1.8 自检

**Windows（PowerShell）**

```powershell
..\scripts\Windows\sanity-check.ps1
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/sanity-check.sh
```

期望看到：

- `.env` 关键变量已设置。
- model deployment 可访问。
- hosted agent 可达并能跑通 `ping`。
- ACR remote build 权限可用。

## 1.9 故障速查

| 现象 | 处理 |
|------|------|
| `azd deploy` 提示缺 `AZURE_AI_PROJECT_ID` | 回 Lab 1 §1.4 重新同步 azd env |
| `azd deploy` ACR push / remote build 慢 | 第一次推 base image 较慢，等待即可 |
| hosted 调用返回 401 | 检查 `.env` 的 `FOUNDRY_API_KEY` 和 project endpoint |
| hosted 调用返回 403 / runtime server error | postdeploy hook 可能未完成赋权；重跑 `azd deploy research-agent` 或联系助教 |
| agent 名冲突 | 确认 `STUDENT_SUFFIX` 是否与讲师分配一致 |
| `azd up` 失败 | 跑错命令；只使用 `azd deploy research-agent` |

→ [Lab 2 · GitHub Copilot vibe coding 业务 agent](../Lab-2-vibe-coding/README.md)
