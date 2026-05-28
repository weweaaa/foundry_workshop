# GitHub Copilot + Microsoft Foundry Hosted Agent · 90min Hands-on Workshop

> 用 5 個 Lab 在 90 分鐘內做出一個**可部署、可呼叫、可觀測**的 Microsoft Foundry hosted agent，並用 GitHub Copilot 迭代 persona / skill / tool。
>
> 學員不建立 Azure 基礎設施。講師會預先準備共享 Foundry account / project / model deployment / ACR；每位學員只部署名稱帶有 `STUDENT_SUFFIX` 的 hosted agent。

## 語言版本

- 簡體中文：[README.md](README.md)
- 繁體中文：[README.zh-TW.md](README.zh-TW.md)
- English: [README.en.md](README.en.md)

## 工作坊協作方式

這不是「照著文件複製命令」的 Lab。每一步都依照同一個 coding-agent-driven 循環推進：

1. **Brief**：人類說明本步目標、業務邊界與驗收標準。
2. **Ask Copilot**：讓 GitHub Copilot coding agent 先讀相關檔案，解釋目前結構，再提出下一步。
3. **Run / Edit**：由 Copilot 協助執行檢查、產生骨架或修改檔案；關鍵命令仍保留在文件中，方便人工審核。
4. **Verify**：用腳本、HTTP 呼叫、lint 或 dashboard 證明結果真的可用。
5. **Reflect**：讓 Copilot 總結差異、失敗原因與下一步，而不是只看「命令有沒有跑完」。

人類負責意圖、業務判斷、安全邊界與最終驗收；Copilot 負責程式碼庫探索、候選修改、命令執行、錯誤歸因與驗證總結。每個 Lab 都會給出明確的 handoff prompt 與 completion signal。

## 30 秒開始

**Windows（PowerShell）**

```powershell
git clone https://github.com/haxudev/foundry_workshop.git
cd foundry_workshop

Copy-Item .env.example .env
notepad .env      # 填入講師提供的 SP、Foundry endpoint/API key、ACR、STUDENT_SUFFIX

code Lab-0-setup\README.zh-TW.md
```

**macOS / Linux（bash）**

```bash
git clone https://github.com/haxudev/foundry_workshop.git
cd foundry_workshop

cp .env.example .env
${EDITOR:-nano} .env

code Lab-0-setup/README.zh-TW.md
```

關鍵約定：

- 倉庫根目錄只維護一份 `.env`；腳本會自動讀取它。
- `chat-hosted.*`、`invoke-hosted.*`、`sanity-check.*` 走 Foundry `api-key` 或 OAuth2 REST，不需要 `az login`。
- `azd deploy` 仍需要 `azd auth login`，且 Lab 1 會把 `.env` 中的部署變數同步到目前的 azd env。
- 不執行 `azd up` / `azd provision`：本工作坊沒有學員側 infra。

## 目錄結構

```text
foundry_workshop/
├── README.md
├── .env.example                    # 複製成 .env，整個 workshop 共用
├── scripts/
│   ├── Windows/                    # PowerShell 7 / Windows PowerShell 5.1
│   ├── macOSLinux/                 # bash 3.2+，需要 curl + jq
│   ├── chat-hosted/index.html      # 本機圖形化 chat UI
│   └── lint-persona.py
├── Lab-0-setup/                    # 工具、憑據、Copilot、azd auth
├── Lab-1-deploy-hosted-agent/      # 第一次把 research-agent 部署到共享 Foundry
├── Lab-2-vibe-coding/              # 本機業務 agent 主程式碼
│   ├── azure.yaml                  # azd deploy 入口，無 infra
│   ├── hooks/postdeploy-grant-roles.ps1
│   ├── personas/
│   ├── skills/
│   ├── tools/
│   ├── src/research_agent/
│   ├── tests/unit/
│   └── .github/                    # Copilot chatmodes / instructions / prompts
├── Lab-3-update-hosted-agent/      # 將本機修改重新發布到 hosted agent
└── Lab-4-observability/            # 本機 HTML + Azure Monitor metrics
```

## 開場架構總覽

一個能上 production 的 agent 不只是「寫個 prompt + 接個模型」。本 workshop 用輕量 harness 把 agent 拆成可版本化、可部署、可觀測的結構：

- **Soul / Persona**：角色邊界、語氣、拒答策略 → `Lab-2-vibe-coding/personas/*.md`
- **Skills**：完成任務的步驟說明書 → `Lab-2-vibe-coding/skills/<skill>/SKILL.md`
- **Tools**：呼叫外部 API / 寫狀態的函式 → `Lab-2-vibe-coding/tools/*.py`
- **Runtime**：模型 + 容器 + 路由 → Microsoft Foundry Hosted Agent

```text
L3 應用層    Hosted Agent 容器 = Agent Framework app     ← Lab 2/3 主戰場
             ├── instructions ← personas/*.md
             ├── context_providers=[SkillsProvider]
             ├── tools=[client-side @tool]
             └── client = FoundryChatClient

L2 模型與工具層  Foundry server-side tools + model deployment ← 講師預先部署
L1 共享基礎設施  Foundry account / project / 模型 / ACR       ← 學員不動
```

預設場景是市場/競品研究助手。想先跑通流程就直接使用預設 `research-agent`；想換成自己的業務，就在 Lab 2 中用 `/persona`、`/skill`、`/tool` 產生自己的三件套。

## 學完你能做到

1. 用 `azd deploy research-agent` 將 Agent Framework Python agent 發布到共享 Foundry project。
2. 用 GitHub Copilot 迭代 **Soul / Persona + Skills + Tools**；現場主路徑是 VS Code Copilot Chat，終端 TUI 只是可選兜底。
3. 本機用 `agentdev run` 除錯業務 agent，再把修改發布到 hosted slot。
4. 用 `api-key` 呼叫 hosted `/responses` endpoint，並開啟本機圖形化 chat UI 多輪對話。
5. 用 Lab 4 的本機 dashboard 查看 AgentResponses、tokens、tool calls、model latency 等 operational metrics。

## 時間結構（90 min）

| # | 環節 | 時長 | 出口產物 |
|---|------|------|----------|
| 0 | [開場 · 架構總覽](#開場架構總覽) | 5 min | 理解共享 Foundry + agent harness + 人機分工 |
| 1 | [Lab 0 · 環境 + 憑據 + Copilot](Lab-0-setup/README.zh-TW.md) | 10 min | readiness check 能說明「可進入 Lab 1」 |
| 2 | [Lab 1 · 首次部署 hosted agent](Lab-1-deploy-hosted-agent/README.zh-TW.md) | 15 min | hosted endpoint 200 OK，Copilot 能解釋部署鏈路 |
| 3 | Buffer | 5 min | — |
| 4 | [Lab 2 · Copilot vibe coding](Lab-2-vibe-coding/README.zh-TW.md) | 30 min | 本機 agent 回傳業務 JSON，persona/skill/tool 有驗收記錄 |
| 5 | [Lab 3 · 更新 hosted agent](Lab-3-update-hosted-agent/README.zh-TW.md) | 10 min | hosted endpoint 回傳更新後的業務 JSON，可解釋 local vs hosted 差異 |
| 6 | [Lab 4 · 本機觀測](Lab-4-observability/README.zh-TW.md) | 10 min | dashboard 顯示自己的 metrics，可解釋指標歸屬 |
| 7 | [Wrap-up](#wrap-up--下一步) | 5 min | 後續學習路徑 |

## Copilot 雙環境

現場主路徑是 **VS Code GitHub Copilot**：它能自動讀取 `Lab-2-vibe-coding/.github/` 裡的 chatmode、instructions 和 prompts。終端裡的 `copilot` TUI 只作為可選兜底，適合無法使用 VS Code Chat 的學員；不要把它寫成舊式命令建議/解釋工作流。

| 環境 | 入口 | 適合 |
|------|------|------|
| VS Code Copilot Chat（建議） | Lab 0 安裝 customization 後，開啟 `Lab-2-vibe-coding/`，選擇 `maf-agent` chatmode，使用 `/persona` `/skill` `/tool` `/deploy` | 產生/修改多檔案 |
| Copilot TUI（可選） | 終端執行 `copilot`，進入 chat 後貼上本 Lab 的 prompt 或模板內容 | 無法使用 VS Code Chat 時的兜底對話路徑 |

兩種環境都可以參考倉庫根目錄 `.agents/skills/` 下的官方 skill：

- `microsoft-foundry` — hosted agent 部署、呼叫、觀測、評估、RBAC、配額
- `agent-framework-azure-ai-py` — Agent Framework Python SDK
- `azure-ai-projects-py` — Azure AI Projects SDK
- `skill-creator` — 建立 / 修訂自訂 skill

## 卡住時怎麼辦

- 先跑對應自檢：Windows `scripts\Windows\sanity-check.ps1`，macOS / Linux `scripts/macOSLinux/sanity-check.sh`。
- 部署失敗只排查 `azd deploy research-agent`，不要修改共享 Foundry / ACR。
- 共享資源只操作自己的 `research-agent-<STUDENT_SUFFIX>`，不要刪除或更新別人的 agent。

## 速查卡

### Copilot 提示語

每個 Lab 的起手模板：

```text
@workspace 我正在做 Lab <N>。請先閱讀本 Lab README 和它引用的腳本/設定檔。
請按這 4 項回答：
1. 人類必須確認什麼
2. 你可以幫我檢查、執行或修改什麼
3. 完成信號是什麼
4. 失敗時最小排查順序是什麼
```

讓 Copilot 先讀再行動：

```text
@workspace 先只讀，不要修改檔案。請閱讀 #file:<path1> #file:<path2>，總結現況、風險和下一個驗證命令。
等我確認後，再開始修改。
```

驗證失敗時：

```text
這是命令輸出。請不要泛泛建議重裝環境。
請基於目前 workshop 約束判斷失敗屬於憑據、azd env、Foundry RBAC、agent runtime 還是程式邏輯；給出最小修復步驟和修完後應重跑的驗證命令。
```

### PowerShell 常用提醒

- 使用服務主體登入 `azd` 時，使用 `--client-secret=$Secret` 或 `--client-secret=$env:AZURE_CLIENT_SECRET`，避免 Windows PowerShell 5.1 把 secret 當成參數前綴吞掉。
- 本 workshop 不執行 `azd up` / `azd provision` / `azd down`，只執行 `azd deploy research-agent`。
- 手動呼叫 hosted agent 時優先用 `scripts/Windows/invoke-hosted.ps1`；它封裝了 api-key、URL 建構和 response 索引。

### Foundry hosted agent API / metrics

- Hosted `/responses` URL：`<endpoint>/agents/<agent-name>/endpoint/protocols/openai/responses?api-version=2025-11-15-preview`
- 日常呼叫：`scripts/Windows/invoke-hosted.ps1 -Prompt "ping"` 或 `scripts/macOSLinux/invoke-hosted.sh --prompt "ping"`
- Lab 4 metrics 查詢使用 Azure Monitor REST API，不走 Foundry api-key；腳本會用 SP 換 ARM token。
- `AgentResponses` 可按 `AgentId` 拆分；`AgentInputTokens`、`AgentOutputTokens`、`AgentToolCalls` 目前在本 workshop 以 project scope 呈現。

## Wrap-up · 下一步

今天完成的是一條 agent 迭代閉環：

```text
Soul / Persona + Skills + Tools
  ↓ agentdev run 本機除錯
Foundry Hosted Agent: research-agent-<STUDENT_SUFFIX>
  ↓ operational metrics 進入 Azure Monitor
Lab 4 本機 dashboard
```

把這套方式帶回團隊時，可以繼續沿用同一節奏：Brief → Ask Copilot → Inspect diff → Verify → Reflect。

下一步可以探索：

- **評估閉環**：把真實呼叫樣本轉成評估資料集，跑 batch eval，比較版本，再優化 prompt / persona。
- **多 agent 編排**：用 workflow 或 connected agents 把多個專職 agent 串起來。
- **MCP server**：把內部能力包裝成 MCP，並在 `agent.manifest.yaml` 中引用。
- **CI/CD**：在 PR 或 nightly 中跑 smoke eval / regression eval。

相關入口：

- [Microsoft Agent Framework](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview)
- [Microsoft Foundry Hosted Agents](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/hosted-agents)
- [`azd ai agent` extension](https://aka.ms/azdaiagent/docs)
- [Foundry Samples (Python)](https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/python/hosted-agents)
- [GitHub Copilot in VS Code](https://aka.ms/vscode-copilot)
- [GitHub Copilot in the terminal](https://docs.github.com/copilot/github-copilot-in-the-cli)