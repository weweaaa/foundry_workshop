# Lab 3 · 把本機業務 agent 更新到 Foundry hosted（10 min）

Lab 2 中你已經在本機除錯了 `src/research_agent/`，或建立了自己的業務 agent。本 Lab 會將修改後的程式重新發布到共享 Foundry project。

## 3.1 目標

- 理解 `agent.yaml.tpl` 與 `agent.manifest.yaml.tpl` 的分工。
- 確認 `azure.yaml` 指向要發布的 agent。
- 用 `azd deploy research-agent` 增量發布。
- 用 hosted endpoint 驗證業務輸出。

## 3.2 Agent-driven 發布方式

Lab 3 的核心不是「再跑一次 deploy」，而是把 Lab 2 的本機產物安全發布到 hosted slot。先讓 Copilot 做一次只讀 release review：

```text
@workspace 我正在做 Lab 3。請閱讀 #file:Lab-2-vibe-coding/azure.yaml、#file:Lab-2-vibe-coding/src/research_agent/agent.yaml.tpl、#file:Lab-2-vibe-coding/src/research_agent/agent.manifest.yaml.tpl、#file:Lab-2-vibe-coding/src/research_agent/main.py 和 #file:Lab-2-vibe-coding/personas/research-agent.md。
請檢查 local artifact 到 hosted agent 的發布鏈路，指出部署前必須確認的 5 件事；不要修改檔案。
```

| 人類負責 | Copilot coding agent 負責 | 完成信號 |
|----------|---------------------------|----------|
| 確認 Lab 2 的業務行為已經驗收，允許覆蓋自己的 hosted agent | 檢查 yaml alignment、解釋 deploy 影響、歸因 hosted 呼叫錯誤 | hosted `/responses` 返回更新後的業務 JSON，guardrail 仍生效 |

## 3.3 兩個 yaml 的分工

| 檔案 | 解決什麼問題 | 主要欄位 |
|------|--------------|----------|
| `src/research_agent/agent.yaml.tpl` | Foundry 如何託管容器；部署前渲染成 `agent.yaml` | `kind: hosted`、`protocols`、`resources`、`environment_variables` |
| `src/research_agent/agent.manifest.yaml.tpl` | agent 執行時使用什麼模型和 server-side tools；部署前渲染成 `agent.manifest.yaml` | `model`、`instructions.file`、`tools` |
| `azure.yaml` | azd 如何建置並發布 service | `host: azure.ai.agent`、`docker.remoteBuild: true`、postdeploy hook |

預設 `research-agent` 已經設定好。自帶業務時，可用 Copilot `/deploy` 產生新目錄的兩個 yaml，再把 `azure.yaml.services` 指向新 service。

## 3.4 配合 Copilot 檢查部署設定

VS Code：

```text
@workspace 檢查 #file:azure.yaml #file:src/research_agent/agent.yaml.tpl #file:src/research_agent/agent.manifest.yaml.tpl 是否適合部署到共享 Foundry project；不要建立 infra，不要本機 Docker build。
```

Copilot TUI（可選）：啟動 `copilot` 進入 chat 後貼上下面這段：

```text
檢查 Lab-2-vibe-coding 的 azure.yaml、src/research_agent/agent.yaml.tpl、src/research_agent/agent.manifest.yaml.tpl。
要求: host=azure.ai.agent, docker.remoteBuild=true, model 用 ${AZURE_AI_MODEL_DEPLOYMENT_NAME}, 不包含 infra。
```

讓 Copilot 輸出時要求它按這個格式：

```text
請按 OK / Risk / Fix 三列列出檢查結果。Risk 只包含會影響 azd deploy 或 hosted runtime 的問題。
```

## 3.5 發布

從 `Lab-2-vibe-coding` 目錄執行。

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

部署完成後，postdeploy hook 會再次為最新版本的 runtime identities 補齊 `AcrPull` 和 `Azure AI User`。這是每個新版本都需要的步驟，腳本是冪等的。

## 3.6 驗證 hosted endpoint

### 圖形化多輪對話（建議）

**Windows（PowerShell）**

```powershell
..\scripts\Windows\chat-hosted.ps1
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/chat-hosted.sh
```

範例問題：

- `幫我研究'消費級 AI 筆記應用'品類，2025 重點對比 5 家`
- `剛才說的第二家，找兩個負面評價`
- `X 公司值不值得投資？`（應觸發 guardrail 拒答）

### 命令列驗證

**Windows（PowerShell）**

```powershell
..\scripts\Windows\invoke-hosted.ps1 `
  -Prompt "幫我研究'消費級 AI 筆記應用'品類，2025 重點對比 5 家"
```

**macOS / Linux（bash）**

```bash
../scripts/macOSLinux/invoke-hosted.sh \
  --prompt "幫我研究《消費級 AI 筆記應用》品類，2025 重點對比 5 家"
```

應返回與本機版本一致的業務 JSON。

### Local vs hosted 對比

如果 Lab 2 的本機服務仍在執行，可以讓 Copilot 幫你設計同一個 prompt 的對比：

```text
我想比較本機 http://localhost:8087/responses 和 hosted invoke-hosted 的輸出。請給我一組最小驗證 prompt：一個成功業務問題、一個多輪上下文問題、一個 guardrail 拒答問題，並說明預期差異。
```

對比時不要求逐字一致；重點看欄位結構、引用策略、拒答邊界和 tool 使用意圖是否一致。

## 3.7 狀態檢查

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

## 3.8 出口檢查點

- `azd deploy research-agent` 完成無錯。
- hosted `/responses` 返回更新後的業務 JSON。
- `sanity-check.*` 全部關鍵項通過。
- Lab 4 前至少呼叫幾次 hosted agent，讓 Monitor metrics 有資料。
- Copilot 能解釋本次發布是否只是業務程式碼更新，還是也改變了 model、server-side tools 或資源設定。

## 3.9 故障速查

| 現象 | 處理 |
|------|------|
| `azd deploy` 提示變數缺失 | 回 Lab 1 §1.4 同步 azd env，尤其 `AZURE_AI_PROJECT_ID` |
| ACR remote build 慢 | 首次建置慢，後續 layer 會複用 |
| hosted 呼叫 401 | 檢查 `FOUNDRY_API_KEY` 與 project endpoint |
| hosted 呼叫 server error | 把錯誤 body 貼給 Copilot；先等 postdeploy RBAC 傳播 1-2 分鐘，必要時重跑 `azd deploy research-agent` |
| instructions 找不到 | `agent.manifest.yaml.instructions.file` 路徑相對 manifest 自身，預設應為 `../../personas/research-agent.md` |
| quota / capacity 錯誤 | 共享 model deployment 被占滿，稍後重試或聯絡講師 |

## 3.10 加分挑戰

1. 在 `agent.manifest.yaml` 中啟用講師已設定好的 server-side tool（例如 Bing grounding）。
2. 改 tool 的 mock/live 行為並重新部署，比較 hosted 輸出差異。
3. 用 Copilot 產生一版自帶業務 agent，再把 `azure.yaml` 指向新 service 發布。

→ [Lab 4 · 本機可觀測性](../Lab-4-observability/README.zh-TW.md)
