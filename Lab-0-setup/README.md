# Lab 0 · 本地环境 + 凭据 + Copilot（10 min）

## 0.1 目标

- 工具链就绪：git、azd、Python、VS Code 或终端、GitHub Copilot。
- 在仓库根目录创建并填写唯一的 `.env`。
- 用讲师下发的服务主体登录 `azd`，为 Lab 1/3 的 `azd deploy` 做准备。
- 启用 VS Code Copilot customization；终端 `copilot` TUI 只作为可选路径。

> 学员不创建 Foundry / 模型 / ACR。共享资源由讲师预部署；你只部署自己的 `research-agent-<STUDENT_SUFFIX>`。

## 0.2 Agent-driven 跑法

本 Lab 的目标不是记住所有工具命令，而是让 Copilot 帮你判断“这台机器能不能进入 Lab 1”。建议先在 Copilot Chat 里发：

```text
@workspace 我正在做 Lab 0。请阅读 #file:Lab-0-setup/README.md、#file:.env.example、#file:scripts/Windows/sanity-check.ps1 和 #file:scripts/macOSLinux/sanity-check.sh。
请帮我列出：需要我手工确认的凭据、你可以运行的检查、以及进入 Lab 1 的完成信号。
```

| 人类负责 | Copilot coding agent 负责 | 完成信号 |
|----------|---------------------------|----------|
| 从讲师处拿到凭据，决定走 VS Code 还是 CLI | 对照 `.env.example` 检查字段、解释脚本输出、归因工具链问题 | `.env` 完整、`azd auth login --check-status` 通过、Copilot 路径可用 |

如果 Copilot 要运行命令，优先让它运行本节后面的真实命令；不要让它生成新的登录脚本或改动凭据文件格式。

## 0.3 工具最低要求

**Windows（PowerShell）**

```powershell
git --version
azd version          # >= 1.21.3
python --version     # >= 3.11
code --version       # 走 VS Code 路径需要
Get-Command copilot  # 走 Copilot TUI 可选路径需要
```

**macOS / Linux（bash）**

```bash
git --version
azd version          # >= 1.21.3
python3 --version    # >= 3.11
code --version       # 走 VS Code 路径需要
command -v copilot   # 走 Copilot TUI 可选路径需要
jq --version         # bash 脚本需要；macOS: brew install jq；Ubuntu: apt-get install jq
```

说明：

- 本工作坊使用 ACR remote build，学员本机**不需要 Docker / Podman**。
- `az` CLI 只作为排障工具，不是主路径；脚本和 Lab 4 都直接用 REST/OAuth2。

## 0.4 Clone 仓库并填写 `.env`

```powershell
git clone https://github.com/haxudev/foundry_workshop.git
cd foundry_workshop
Copy-Item .env.example .env
notepad .env
```

```bash
git clone https://github.com/haxudev/foundry_workshop.git
cd foundry_workshop
cp .env.example .env
${EDITOR:-nano} .env
```

讲师会提供这些字段：

```text
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_CLIENT_ID
AZURE_CLIENT_SECRET
AZURE_LOCATION

AZURE_AI_PROJECT_ENDPOINT
AZURE_AI_PROJECT_ID
AZURE_AI_MODEL_DEPLOYMENT_NAME
FOUNDRY_API_KEY

AZURE_CONTAINER_REGISTRY_NAME
AZURE_CONTAINER_REGISTRY_ENDPOINT
STUDENT_SUFFIX
```

让 Copilot 做一次字段完整性检查，但不要把 secret 贴进聊天。可以问：

```text
@workspace 只根据 #file:.env.example 的字段名，检查我的 .env 是否应该包含哪些 key；不要要求我粘贴 secret 值。
```

## 0.5 登录 azd（部署专用）

**Windows（PowerShell）**

```powershell
. .\scripts\Windows\load-env.ps1
azd auth login --client-id $env:AZURE_CLIENT_ID --tenant-id $env:AZURE_TENANT_ID --client-secret=$env:AZURE_CLIENT_SECRET
azd config set defaults.subscription $env:AZURE_SUBSCRIPTION_ID
azd auth login --check-status
```

**macOS / Linux（bash）**

```bash
source scripts/macOSLinux/load-env.sh
azd auth login --client-id "$AZURE_CLIENT_ID" --tenant-id "$AZURE_TENANT_ID" --client-secret "$AZURE_CLIENT_SECRET"
azd config set defaults.subscription "$AZURE_SUBSCRIPTION_ID"
azd auth login --check-status
```

> 不需要 `az login`。如果后续手动使用 `az` 排障，再按需登录即可。

## 0.6 安装 azd ai agent 扩展

```powershell
azd extension install azure.ai.agents
azd extension list
```

确认列表里有 `azure.ai.agents`。

## 0.7 启用 Copilot（二选一）

### 路径 A · VS Code Copilot Chat（推荐）

**Windows（PowerShell）**

```powershell
.\scripts\Windows\install-maf-copilot-skills.ps1
cd Lab-2-vibe-coding
code .
```

**macOS / Linux（bash）**

```bash
./scripts/macOSLinux/install-maf-copilot-skills.sh
cd Lab-2-vibe-coding
code .
```

在 VS Code 中打开 Copilot Chat，顶部选择 `maf-agent` chatmode。试输入：

```text
@workspace 列出当前 workshop 支持哪些 Copilot prompts 和 skills
```

### 路径 B · Copilot TUI（可选）

```powershell
copilot
```

进入 chat 后输入：

```text
请根据当前目录解释这个 workshop 的 Lab 0 readiness check；如果需要上下文，我会粘贴 README 或脚本片段。
```

TUI 路径不会像 VS Code Copilot Chat 一样自动使用 `maf-agent` chatmode、instructions 和 slash prompts。需要 Foundry 或 Agent Framework 背景时，把对应 `SKILL.md` 或 `.github/prompts/*.prompt.md` 内容粘进 chat。Copilot 提示语速查已合并到 [`../README.md`](../README.md#速查卡)。

## 0.8 出口检查点

```powershell
azd auth login --check-status
.\scripts\Windows\sanity-check.ps1
```

```bash
azd auth login --check-status
./scripts/macOSLinux/sanity-check.sh
```

继续 Lab 1 前确认：

- `.env` 已填写完整。
- `azd auth login --check-status` 退出码为 0。
- 选择的 Copilot 路径可用。
- `sanity-check.*` 的 `.env` / model / ACR 权限项通过；hosted agent 项在 Lab 1 部署前可能还是失败，属于正常。

把输出交给 Copilot 时，用这个问法收尾：

```text
这是 Lab 0 readiness check 的输出。请判断我能否进入 Lab 1；如果不能，只列出最小修复步骤，不要建议创建 Azure 资源。
```

## 0.9 故障速查

| 现象 | 处理 |
|------|------|
| `azd auth login` 报 `AADSTS7000215` | secret 填错或被 shell 转义；回到 `.env` 对照讲师提供值 |
| PowerShell secret 含特殊字符登录失败 | 使用 `--client-secret=$env:AZURE_CLIENT_SECRET`，不要写成空格分隔 |
| `azd extension install` 网络超时 | 换网络，或找助教提供离线扩展包 |
| Copilot Chat 看不到 `maf-agent` | 重新跑 `install-maf-copilot-skills.*`，然后 `Developer: Reload Window` |
| `copilot` 命令不存在或要登录 | 优先使用 VS Code 主路径；需要终端路径时找助教完成 Copilot TUI 安装/登录 |

→ [Lab 1 · 首次部署 hosted agent](../Lab-1-deploy-hosted-agent/README.md)
