# Lab 1 · 用 Copilot + azd 部署你的第一个 hosted agent(30 min)

## 1.1 目标

- 理解 `azd ai agent init -m <manifest>` 如何把一个 Foundry 提供的 placeholder agent 注入 `azure.yaml`
- 用一条 `azd deploy` 把它部署到讲师指定的共享 project,名字带 `STUDENT_SUFFIX` 区分
- 拿到自己 agent 的 **预览 URL** 并跑通一次 invoke

> 学员不创建任何 Foundry / 模型 / ACR 资源。共享资源由讲师在配套仓库中预部署。本 Lab 只把一个 placeholder agent 包装成"自己的 hosted agent"部署到共享 project。

## 1.2 配合 Copilot

本 Lab 的几个步骤都可以让 Copilot 协助。两种环境二选一:

| 步骤 | VS Code 走法 | Copilot CLI 走法 |
|------|------------|------|
| 读懂 `azure.yaml` | `@workspace 解释 #file:azure.yaml` | `gh copilot explain "azd deploy <agent> with no infra block"` |
| 改 placeholder 的 model | `/deploy` 斜杠命令 | 把 `.github/prompts/deploy.prompt.md` 内容 + `agent.manifest.yaml` 内容粘进 `gh copilot suggest` |
| `azd deploy` 出错排查 | `@workspace 这个 azd deploy 报错是什么原因 …(粘错误)` | `gh copilot explain "<错误信息>"` |
| 部署 / RBAC / quota 深入参考 | 直接问 chat,关键词命中后自动加载 `.agents/skills/microsoft-foundry/` | 拼上 `.agents/skills/microsoft-foundry/foundry-agent/deploy/deploy.md` 作为 context |

## 1.3 进入 Lab-2-vibe-coding 并把讲师凭据灌进 azd env

```powershell
cd workshop\Lab-2-vibe-coding
azd init -e dev --no-prompt        # 不会创建任何资源;只是建本地 azd env

# 讲师下发的字段(也可直接 sourcing .env)
azd env set AZURE_SUBSCRIPTION_ID         <subId>
azd env set AZURE_LOCATION                eastus2

# 共享 Foundry 资源(讲师提供,所有人相同)
azd env set AZURE_AI_PROJECT_ENDPOINT     "<讲师给的 project endpoint>"
azd env set AZURE_AI_MODEL_DEPLOYMENT_NAME <讲师给的模型 deployment 名,如 gpt-5-mini>

# 学员后缀 + agent 名(讲师分配)
azd env set STUDENT_SUFFIX                stuNN
azd env set AGENT_NAME                    research-agent-stuNN

# 共享 ACR(讲师提供,所有人相同)
azd env set AZURE_CONTAINER_REGISTRY_NAME     <讲师给的 ACR 名>
azd env set AZURE_CONTAINER_REGISTRY_ENDPOINT <讲师给的 ACR 登录端点>
```

> 💡 不要执行 `azd up`:本工作坊**没有任何 infra bicep** 给学员,`azd up` 一定失败。只用 `azd deploy <agent>`。

## 1.4 用 Copilot 看一下 azure.yaml

**VS Code**:打开 `azure.yaml`,在 Copilot Chat(`maf-agent` chatmode)输入:

```
@workspace 解释 #file:azure.yaml 的 services.research-agent 字段;
为什么没有 deployments 数组 / 为什么没有 infra 块。
```

**Copilot CLI**:

```powershell
$yaml = Get-Content azure.yaml -Raw
gh copilot explain "解释这段 azure.yaml 为什么没有 infra 块、deployments 为空:`n$yaml"
```

期望回答两点:

- `deployments: []` 表示不让 azd 创建模型 deployment —— 共享 deployment 是讲师建好的。
- 没有 `infra:` 是因为学员 SP 没有 RG provision 权限;只能调 `azd deploy`。

## 1.5 注入 Foundry placeholder agent

用 Foundry 官方 sample 的 manifest 作为基础:

```powershell
# 必须用 agent.manifest.yaml(AgentManifest schema),不是 agent.yaml。
azd ai agent init -m https://github.com/azure-ai-foundry/foundry-samples/blob/main/samples/python/hosted-agents/agent-framework/responses/01-basic/agent.manifest.yaml
```

执行后:

- `azure.yaml` 的 `services` 会被 azd ai agent ext 修改 / 追加。
- `src/` 下会多出一个 `agent-framework-agent-basic-responses/` 目录。

### ⚠️ Sample 默认 `gpt-4.1-mini` 不存在,先 patch

Sample 的 `agent.manifest.yaml` 里 `model:` 写死了 `gpt-4.1-mini`,共享 project 上没部署这个模型。改成引用学员 azd env 的变量:

**Windows（PowerShell）**

```powershell
$mf = "src\agent-framework-agent-basic-responses\agent.manifest.yaml"
(Get-Content $mf -Raw) -replace 'gpt-4\.1-mini', '${AZURE_AI_MODEL_DEPLOYMENT_NAME}' | Set-Content $mf -NoNewline
```

**macOS / Linux（bash）**

```bash
mf="src/agent-framework-agent-basic-responses/agent.manifest.yaml"
sed -i.bak 's/gpt-4\.1-mini/${AZURE_AI_MODEL_DEPLOYMENT_NAME}/g' "$mf" && rm "$mf.bak"
```

**VS Code 学员**可直接用 `/deploy` 斜杠让 Copilot 帮你重写:

```
/deploy agentDir=agent-framework-agent-basic-responses agentDeployName=research-agent-${STUDENT_SUFFIX}
```

**Copilot CLI 学员** 用模板:

**Windows（PowerShell）**

```powershell
$prompt = @"
参考 src/research_agent/agent.manifest.yaml 已有写法,把
src/agent-framework-agent-basic-responses/agent.manifest.yaml 改造成:
1. model 引用 \${AZURE_AI_MODEL_DEPLOYMENT_NAME}
2. name 改成 research-agent-\${STUDENT_SUFFIX}
3. 保留原 tools / instructions 部分
"@
gh copilot suggest $prompt
```

**macOS / Linux（bash）**

```bash
prompt=$(cat <<'EOF'
参考 src/research_agent/agent.manifest.yaml 已有写法，把
src/agent-framework-agent-basic-responses/agent.manifest.yaml 改造成：
1. model 引用 ${AZURE_AI_MODEL_DEPLOYMENT_NAME}
2. name 改成 research-agent-${STUDENT_SUFFIX}
3. 保留原 tools / instructions 部分
EOF
)
gh copilot suggest "$prompt"
```

### 让 placeholder 用学员后缀命名

把 quickstart agent 的 yaml 里 `name:` 改成 `research-agent-<STUDENT_SUFFIX>`(azd env 会替换变量)。本 Lab 主要目的是先跑通一次部署,保留改名即可;Lab 3 你会把它替换为 `src/research_agent/` 这个真正的业务实现。

## 1.6 部署

```powershell
azd deploy
```

`azd deploy` 会:

1. 通过 ACR remote build 打镜像(标签自动带学员后缀)→ push 到共享 `cr<token>.azurecr.io`。
2. 调 Foundry control plane 在共享 project 上 create/update **你这个** hosted agent。
3. 把 hosted endpoint 与 responses URL 写回 azd env:
   - `AGENT_<UPPER_SNAKE_NAME>_ENDPOINT`
   - `AGENT_<UPPER_SNAKE_NAME>_RESPONSES_ENDPOINT`

等待期间讲师讲解 6 个 azd hook 阶段(pre-package / package / publish ACR / agent publish / post hook)。

## 1.7 拿预览 URL 跑一次

两条路径任选, **二选一**:

**🖥️  图形化聊天 (推荐, 像 ChatGPT 一样多轮对话)**

**Windows（PowerShell）**

```powershell
..\scripts\Windows\chat-hosted.ps1
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/chat-hosted.sh
```

脚本会:

1. 从 `.env` / 进程 env / azd env 读 SP 凭据 + endpoint + agent name
2. **直接 OAuth2 client_credentials grant** 拿 AAD token (audience `https://ai.azure.com/.default`) —— **不依赖 `az login`, 不依赖 `azd auth`**, 学员只要 SP 凭据填好就行
3. 把 endpoint / agent / token 注入到本地单文件 HTML 的 `#cfg=` URL hash
4. 在默认浏览器中打开 chat UI

打开后你会看到一个深色聊天界面, 输入消息按 Enter 即可. UI 直接调 `/responses` 端点; 多轮上下文保留在页面里; 失败时显示 HTTP 状态 + 原始 body 方便排错. **不需要登 Azure Portal, 也不需要 az CLI**.

> token 仅注入到本地 URL hash, 不会发送到任何第三方服务. 一般 1 小时左右失效, 重跑 `chat-hosted.ps1` / `chat-hosted.sh` 即可换新.

**💻  命令行单次验证 (适合自动化 / CI; 用 az 拿 token)**

**Windows（PowerShell）**

```powershell
azd env get-value AGENT_RESEARCH_AGENT_${env:STUDENT_SUFFIX}_RESPONSES_ENDPOINT
# 或直接用脚本
..\scripts\Windows\invoke-hosted.ps1 -AgentName "research-agent-$env:STUDENT_SUFFIX" -Prompt "ping"
```

**macOS / Linux（bash）**

```bash
azd env get-value "AGENT_RESEARCH_AGENT_${STUDENT_SUFFIX}_RESPONSES_ENDPOINT"
# 或直接用脚本
../scripts/macOSLinux/invoke-hosted.sh --agent-name "research-agent-${STUDENT_SUFFIX}" --prompt "ping"
```

返回 JSON 含 `output_text` 即 OK.

> 想了解 `/responses` 协议细节、SSE 流式、错误码,直接问 Copilot:`@workspace 参考 #file:.agents/skills/microsoft-foundry/foundry-agent/invoke/invoke.md,解释 hosted agent 的 invocations 协议`(CLI 学员把 SKILL 内容拼到 prompt)。

## 1.8 自检

**Windows（PowerShell）**

```powershell
..\scripts\Windows\sanity-check.ps1
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/sanity-check.sh
```

应输出:

```
✅ AZURE_AI_PROJECT_ENDPOINT 已设置
✅ AZURE_AI_MODEL_DEPLOYMENT_NAME 已设置
✅ STUDENT_SUFFIX 已设置
✅ AZURE_CONTAINER_REGISTRY_NAME 已设置
✅ az 已登录
✅ ai.azure.com access token
✅ 模型 deployment 'gpt-5-mini' 在共享 project 中
✅ Hosted agent 'research-agent-stuNN' 可达
✅ ACR 'cr...' 可推送
```

## 1.9 出口检查点

✅ `azd deploy` 完成,无错
✅ `invoke-hosted.ps1` / `invoke-hosted.sh` 返回 200,JSON 含 `output_text`
✅ `sanity-check.ps1` / `sanity-check.sh` 全 ✅

## 1.10 故障速查

| 现象 | 处理 |
|------|------|
| `azd deploy` ACR push 卡住 | 等;第一次推 base image 慢,后续 layer 会复用 |
| `image platform does not match host platform` | 确认 `docker.remoteBuild: true`;本地不要本地构建 |
| 调 hosted agent 报 `PermissionDenied … AIServices/agents/read` | 学员 SP 没在共享 project 上拿到 `Azure AI User`,联系讲师 |
| Hosted agent 名冲突(已存在) | 别人占了你的后缀;确认讲师分配的 `STUDENT_SUFFIX` 是不是和你 SP 实际匹配 |
| `azd ai agent init` 报 "Loading the model catalog" 卡死 | sample 引用了未部署的模型;按 1.5 节 patch |
| `azd up` 报 `AuthorizationFailed` | 你跑成 `azd up` 了 —— 本工作坊只用 `azd deploy` |

## 1.11 等待期"动脑"任务

`azd deploy` 等的时候,提前读:

- `Lab-2-vibe-coding/personas/research-agent.md` —— Lab 2 你会改它
- `Lab-2-vibe-coding/skills/market-research/SKILL.md` —— Lab 2 的流程主线
- `.agents/skills/microsoft-foundry/foundry-agent/deploy/deploy.md` —— 想深入了解 Foundry hosted agent 的部署细节

→ [Lab 2 · vibe coding 业务 agent](../Lab-2-vibe-coding/HANDBOOK.md)
