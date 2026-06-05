# Lab 1 · 首次部署你的 Foundry hosted agent（15 min）

## 1.1 目標

- 理解目前倉庫為什麼只有 `azd deploy`，沒有 `azd up` / infra。
- 將 `.env` 中的部署變數同步到 Lab 2 的 azd env。
- 用 `azd deploy research-agent` 把參考實作發布到共享 Foundry project。
- 用本機圖形 chat 或命令列腳本驗證 hosted `/responses` endpoint。

> Lab 1 先部署倉庫內建的 `research-agent`。Lab 2 會在本機修改業務邏輯，Lab 3 再把修改後的版本重新發布。

## 1.2 Agent-driven 跑法

把 Lab 1 當成一次可審計的發布，而不是一串 `azd` 命令。先讓 Copilot 讀部署入口並解釋它將驗證什麼：

```text
@workspace 我正在做 Lab 1。請閱讀 #file:Lab-2-vibe-coding/azure.yaml、#file:Lab-2-vibe-coding/src/research_agent/agent.yaml、#file:Lab-2-vibe-coding/src/research_agent/agent.manifest.yaml 和 #file:Lab-2-vibe-coding/hooks/postdeploy-grant-roles.ps1。
請先解釋部署會做什麼、為什麼不能執行 azd up，以及部署後的完成信號。
```

| 人類負責 | Copilot coding agent 負責 | 完成信號 |
|----------|---------------------------|----------|
| 確認 `.env` 來自講師、同意部署自己的 `research-agent-<STUDENT_SUFFIX>` | 檢查 azd env 是否缺欄位、解釋 `azure.yaml`、歸因 deploy / invoke 錯誤 | `azd deploy research-agent` 成功，`invoke-hosted.* -Prompt ping` 返回 completed |

## 1.3 配合 Copilot

| 任務 | VS Code 走法（主路徑） | Copilot TUI 走法（可選） |
|------|--------------|------------------|
| 解釋 `azure.yaml` | `@workspace 解釋 #file:azure.yaml 的 services.research-agent` | 執行 `copilot` 進入 chat，貼上 `azure.yaml` 相關片段並問同樣問題 |
| 看懂部署 metadata | `#file:src/research_agent/agent.yaml #file:src/research_agent/agent.manifest.yaml explain the difference` | 貼上兩個 yaml 的相關內容，讓 TUI chat 對比分工 |
| 部署失敗排查 | 貼上 `azd deploy` 錯誤並要求只分析本 workshop 路徑 | 貼上錯誤輸出，讓 TUI chat 只圍繞本 workshop 約束排查 |

## 1.4 初始化 azd env 並同步變數

從倉庫根目錄開始。

**Windows（PowerShell）**

```powershell
. .\scripts\Windows\load-env.ps1
cd Lab-2-vibe-coding
azd init -e dev --no-prompt

azd env set AZURE_SUBSCRIPTION_ID $env:AZURE_SUBSCRIPTION_ID
azd env set AZURE_LOCATION $env:AZURE_LOCATION
azd env set AZURE_AI_PROJECT_ENDPOINT $env:AZURE_AI_PROJECT_ENDPOINT
azd env set FOUNDRY_PROJECT_ENDPOINT $env:AZURE_AI_PROJECT_ENDPOINT
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
azd env set FOUNDRY_PROJECT_ENDPOINT "$AZURE_AI_PROJECT_ENDPOINT"
azd env set AZURE_AI_PROJECT_ID "$AZURE_AI_PROJECT_ID"
azd env set AZURE_AI_MODEL_DEPLOYMENT_NAME "$AZURE_AI_MODEL_DEPLOYMENT_NAME"
azd env set AZURE_CONTAINER_REGISTRY_NAME "$AZURE_CONTAINER_REGISTRY_NAME"
azd env set AZURE_CONTAINER_REGISTRY_ENDPOINT "$AZURE_CONTAINER_REGISTRY_ENDPOINT"
azd env set STUDENT_SUFFIX "$STUDENT_SUFFIX"
azd env set AGENT_NAME "research-agent-${STUDENT_SUFFIX}"
```

> `azd env` 只保存部署需要的非互動變數；腳本和 postdeploy hook 仍會讀取倉庫根 `.env`。

同步完成後可以讓 Copilot 幫你做一次只讀核對：

```text
我已經執行 Lab 1 的 azd env set。請告訴我還應該用哪些 azd env get-value 命令核對變數，不要修改任何檔案。
```

## 1.5 看懂 Lab 2 的部署入口

在 `Lab-2-vibe-coding/azure.yaml` 裡，核心資訊只有一個 service：

```yaml
services:
  research-agent:
    project: src/research_agent
    host: azure.ai.agent
    language: docker
    docker:
      remoteBuild: true
```

要點：

- `remoteBuild: true` 表示映像由 ACR remote build 完成，不要求學員本機安裝 Docker。
- 沒有 `infra:`，因為共享 Foundry / ACR 已由講師建立。
- `hooks.postdeploy` 會自動給 Foundry 為該 agent 版本建立的 managed identities 授 `AcrPull` 和 `Azure AI User`。

## 1.6 部署

```powershell
azd deploy research-agent
```

部署會做三件事：

1. 用 ACR remote build 建置並推送映像。
2. 在共享 Foundry project 中 create/update `research-agent-<STUDENT_SUFFIX>`。
3. 執行 postdeploy hook，補齊該版本 runtime identity 的拉映像與調模型權限。

> 不要執行 `azd up`。本工作坊沒有學員側 infra，`azd up` / `azd provision` 不是正確路徑。

## 1.7 驗證 hosted endpoint

### 圖形化聊天（建議）

**Windows（PowerShell）**

```powershell
..\scripts\Windows\chat-hosted.ps1
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/chat-hosted.sh
```

腳本會讀取根目錄 `.env` 裡的 `FOUNDRY_API_KEY`、project endpoint 和 agent name，開啟本機 HTML chat UI。憑據只放在本機 URL hash 中，不會傳給第三方。

### 命令列驗證

**Windows（PowerShell）**

```powershell
..\scripts\Windows\invoke-hosted.ps1 -Prompt "ping"
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/invoke-hosted.sh --prompt "ping"
```

返回 JSON 中 `status` 為 `completed`，且有文字輸出即通過。

讓 Copilot 根據驗證結果做一次發布復盤：

```text
這是 invoke-hosted 的輸出。請判斷 Lab 1 是否完成，並用 3 條說明 hosted agent、FOUNDRY_API_KEY、postdeploy RBAC 分別是否正常。
```

## 1.8 自檢

**Windows（PowerShell）**

```powershell
..\scripts\Windows\sanity-check.ps1
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/sanity-check.sh
```

期望看到：

- `.env` 關鍵變數已設定。
- model deployment 可存取。
- hosted agent 可達並能跑通 `ping`。
- ACR remote build 權限可用。

## 1.9 故障速查

| 現象 | 處理 |
|------|------|
| `azd deploy` 提示缺 `AZURE_AI_PROJECT_ID` | 回 Lab 1 §1.4 重新同步 azd env |
| `azd deploy` ACR push / remote build 慢 | 第一次推 base image 較慢，等待即可 |
| hosted 呼叫返回 401 | 檢查 `.env` 的 `FOUNDRY_API_KEY` 和 project endpoint |
| hosted 呼叫返回 403 / runtime server error | postdeploy hook 可能尚未完成賦權；重跑 `azd deploy research-agent` 或聯絡助教 |
| agent 名稱衝突 | 確認 `STUDENT_SUFFIX` 是否與講師分配一致 |
| `azd up` 失敗 | 跑錯命令；只使用 `azd deploy research-agent` |

→ [Lab 2 · GitHub Copilot vibe coding 業務 agent](../Lab-2-vibe-coding/README.zh-TW.md)
