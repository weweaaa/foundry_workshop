# Lab 0 · 本機環境 + 憑據 + Copilot（10 min）

## 0.1 目標

- 工具鏈就緒：git、azd、Python、VS Code 或終端、GitHub Copilot。
- 在倉庫根目錄建立並填寫唯一的 `.env`。
- 用講師提供的服務主體登入 `azd`，為 Lab 1/3 的 `azd deploy` 做準備。
- 啟用 VS Code Copilot customization；終端 `copilot` TUI 只作為可選路徑。

> 學員不建立 Foundry / 模型 / ACR。共享資源由講師預先部署；你只部署自己的 `research-agent-<STUDENT_SUFFIX>`。

## 0.2 Agent-driven 跑法

本 Lab 的目標不是記住所有工具命令，而是讓 Copilot 幫你判斷「這台機器能不能進入 Lab 1」。建議先在 Copilot Chat 中發：

```text
@workspace 我正在做 Lab 0。請閱讀 #file:Lab-0-setup/README.md、#file:.env.example、#file:scripts/Windows/sanity-check.ps1 和 #file:scripts/macOSLinux/sanity-check.sh。
請幫我列出：需要我手動確認的憑據、你可以執行的檢查、以及進入 Lab 1 的完成信號。
```

| 人類負責 | Copilot coding agent 負責 | 完成信號 |
|----------|---------------------------|----------|
| 從講師取得憑據，決定走 VS Code 還是 TUI | 對照 `.env.example` 檢查欄位、解釋腳本輸出、歸因工具鏈問題 | `.env` 完整、`azd auth login --check-status` 通過、Copilot 路徑可用 |

如果 Copilot 要執行命令，優先讓它執行本節後面的真實命令；不要讓它產生新的登入腳本或改動憑據檔格式。

## 0.3 工具最低要求

**Windows（PowerShell）**

```powershell
git --version
azd version          # >= 1.21.3
python --version     # >= 3.11
code --version       # 走 VS Code 路徑需要
Get-Command copilot  # 走 Copilot TUI 可選路徑需要
```

**macOS / Linux（bash）**

```bash
git --version
azd version          # >= 1.21.3
python3 --version    # >= 3.11
code --version       # 走 VS Code 路徑需要
command -v copilot   # 走 Copilot TUI 可選路徑需要
jq --version         # bash 腳本需要；macOS: brew install jq；Ubuntu: apt-get install jq
```

說明：

- 本工作坊使用 ACR remote build，學員本機**不需要 Docker / Podman**。
- `az` CLI 只作為排障工具，不是主路徑；腳本和 Lab 4 都直接用 REST/OAuth2。

## 0.4 Clone 倉庫並填寫 `.env`

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

講師會提供這些欄位：

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

讓 Copilot 做一次欄位完整性檢查，但不要把 secret 貼進聊天。可以問：

```text
@workspace 只根據 #file:.env.example 的欄位名稱，檢查我的 .env 應該包含哪些 key；不要要求我貼上 secret 值。
```

## 0.5 登入 azd（部署專用）

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

> 不需要 `az login`。如果後續手動使用 `az` 排障，再按需登入即可。

## 0.6 安裝 azd ai agent 擴充

```powershell
azd extension install azure.ai.agents
azd extension list
```

確認清單裡有 `azure.ai.agents`。

## 0.7 啟用 Copilot（二選一）

### 路徑 A · VS Code Copilot Chat（建議）

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

在 VS Code 中開啟 Copilot Chat，頂部選擇 `maf-agent` chatmode。試輸入：

```text
@workspace 列出目前 workshop 支援哪些 Copilot prompts 和 skills
```

### 路徑 B · Copilot TUI（可選）

```powershell
copilot
```

進入 chat 後輸入：

```text
請根據目前目錄解釋這個 workshop 的 Lab 0 readiness check；如果需要上下文，我會貼上 README 或腳本片段。
```

TUI 路徑不會像 VS Code Copilot Chat 一樣自動使用 `maf-agent` chatmode、instructions 和 slash prompts。需要 Foundry 或 Agent Framework 背景時，把對應 `SKILL.md` 或 `.github/prompts/*.prompt.md` 內容貼進 chat。Copilot 提示語速查已合併到 [`../README.zh-TW.md`](../README.zh-TW.md#速查卡)。

## 0.8 出口檢查點

```powershell
azd auth login --check-status
.\scripts\Windows\sanity-check.ps1
```

```bash
azd auth login --check-status
./scripts/macOSLinux/sanity-check.sh
```

繼續 Lab 1 前確認：

- `.env` 已填寫完整。
- `azd auth login --check-status` 退出碼為 0。
- 選擇的 Copilot 路徑可用。
- `sanity-check.*` 的 `.env` / model / ACR 權限項通過；hosted agent 項在 Lab 1 部署前可能還是失敗，這是正常的。

把輸出交給 Copilot 時，用這個問法收尾：

```text
這是 Lab 0 readiness check 的輸出。請判斷我能否進入 Lab 1；如果不能，只列出最小修復步驟，不要建議建立 Azure 資源。
```

## 0.9 故障速查

| 現象 | 處理 |
|------|------|
| `azd auth login` 報 `AADSTS7000215` | secret 填錯或被 shell 轉義；回到 `.env` 對照講師提供值 |
| PowerShell secret 含特殊字元登入失敗 | 使用 `--client-secret=$env:AZURE_CLIENT_SECRET`，不要寫成空格分隔 |
| `azd extension install` 網路逾時 | 換網路，或找助教提供離線擴充包 |
| Copilot Chat 看不到 `maf-agent` | 重新跑 `install-maf-copilot-skills.*`，然後 `Developer: Reload Window` |
| `copilot` 命令不存在或要登入 | 優先使用 VS Code 主路徑；需要終端路徑時找助教完成 Copilot TUI 安裝/登入 |

→ [Lab 1 · 首次部署 hosted agent](../Lab-1-deploy-hosted-agent/README.zh-TW.md)