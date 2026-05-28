# Lab 4 · 本機 Observability：Foundry operational metrics（10 min）

Lab 4 用本機 HTML 查看 hosted agent 的 operational metrics：我的 AgentResponses、project tokens、tool calls、各 agent share、model latency。資料來自 Azure Monitor REST API，不走 Portal / App Insights，也不需要 `az login`。

> 不使用 Azure Portal，不依賴 Application Insights，不要求 `az login`。

## 4.1 目標

- 製造幾次 hosted agent 呼叫，讓 Monitor 有資料。
- 用 `fetch-traces.ps1` / `fetch-traces.sh` 寫出 `data/my-metrics.js`。
- 開啟本機 `index.html` 查看 metrics dashboard。
- 理解哪些指標是按 agent 拆分，哪些是 project/account 層級共享指標。

## 4.2 Agent-driven 觀測方式

這個目錄不需要 Copilot 幫你建立 Azure 資源。它主要做三件事：產生測試 prompt、解釋 `fetch-traces.*` 輸出、幫助擴充 `index.html` 圖表。

```text
@workspace 我正在做 Lab 4。請閱讀 #file:Lab-4-observability/README.md、#file:Lab-4-observability/fetch-traces.ps1、#file:Lab-4-observability/fetch-traces.sh 和 #file:Lab-4-observability/index.html。
請告訴我如何產生最小測試流量、拉取 metrics、判斷 dashboard 是否完成。
```

| 人類負責 | Copilot coding agent 負責 | 完成信號 |
|----------|---------------------------|----------|
| 判斷測試問題是否符合業務和安全邊界 | 產生測試 prompt 集、解釋腳本輸出、定位 metrics 為空的原因 | `data/my-metrics.js` 寫出，`我的 AgentResponses` 大於 0，能解釋指標粒度 |

## 4.3 配合 Copilot

| 任務 | VS Code 走法（主路徑） | Copilot TUI 走法（可選） |
|------|--------------|------------------|
| 解釋 dashboard 指標 | `@workspace 解釋 #file:Lab-4-observability/index.html 的 KPI` | 執行 `copilot` 進入 chat，貼上指標名或截圖文字 |
| 排查 metrics 為空 | 貼上 `fetch-traces.*` 輸出 | 貼上錯誤回應和本 Lab 約束，讓 TUI chat 做最小排查 |
| 產生測試問題集 | `@workspace 根據 persona 產生 5 條 hosted 呼叫 prompt` | 貼上 persona / skill 摘要，讓 TUI chat 產生測試 prompt 集 |
| 擴充圖表 | `#file:index.html add a chart for project_tool_calls` | 貼上修改目標；涉及多檔案修改時仍建議回到 VS Code 主路徑 |
| 深入 Foundry observability | 詢問 `microsoft-foundry observe / trace` | 拼上 `.agents/skills/microsoft-foundry/foundry-agent/observe/` 相關文件 |

## 4.4 檔案

| 檔案 | 用途 |
|------|------|
| `index.html` | 本機 dashboard；顯示我的 AgentResponses、project tokens、各 agent share、model latency |
| `fetch-traces.ps1` | Windows 版 metrics 拉取腳本，輸出 `data/my-metrics.js` |
| `fetch-traces.sh` | macOS / Linux 版，依賴 `curl` + `jq`，輸出格式與 PowerShell 版一致 |
| `data/my-metrics.js` | 腳本產生的資料檔（gitignore） |
| `data/responses.jsonl` | `invoke-hosted.*` 追加的 response 索引（gitignore，供後續擴充用） |

## 4.5 製造 metrics

先讓 Copilot 根據 persona 產生覆蓋面，而不是手寫隨機問題：

```text
@workspace 根據 #file:Lab-2-vibe-coding/personas/research-agent.md 和 #file:Lab-2-vibe-coding/skills/market-research/SKILL.md，產生 5 條 Lab 4 hosted 呼叫 prompt：3 條成功研究、1 條 guardrail 拒答、1 條可能觸發工具失敗。輸出 PowerShell 和 bash 陣列，不要包含敏感資訊。
```

下面是預設最小集合；你也可以替換成 Copilot 產生的業務集合。從 `Lab-2-vibe-coding` 目錄執行。

**Windows（PowerShell）**

```powershell
$prompts = @(
  "幫我研究'消費級 AI 筆記應用'品類，2025 重點對比 5 家",
  "對比國內三大新茶飲品牌 2024 增速",
  "X 公司值不值得投資？買入還是賣出？"
)
foreach ($p in $prompts) {
  ..\scripts\Windows\invoke-hosted.ps1 -Prompt $p
  Start-Sleep -Seconds 2
}
```

**macOS / Linux（bash）**

```bash
prompts=(
  "幫我研究《消費級 AI 筆記應用》品類，2025 重點對比 5 家"
  "對比國內三大新茶飲品牌 2024 增速"
  "X 公司值不值得投資？買入還是賣出？"
)
for p in "${prompts[@]}"; do
  ../scripts/macOSLinux/invoke-hosted.sh --prompt "$p"
  sleep 2
done
```

等待 1-2 分鐘，讓 Azure Monitor 完成攝入。

## 4.6 拉取 metrics

**Windows（PowerShell）**

```powershell
..\Lab-4-observability\fetch-traces.ps1 -Minutes 60 -Interval PT5M
# 寫出 ...\Lab-4-observability\data\my-metrics.js
```

**macOS / Linux（bash）**

```bash
../Lab-4-observability/fetch-traces.sh --minutes 60 --interval PT5M
# 寫出 .../Lab-4-observability/data/my-metrics.js
```

常用參數：

| PowerShell | bash | 含義 |
|------------|------|------|
| `-Minutes 60` | `--minutes 60` | 查詢時間窗口 |
| `-Interval PT5M` | `--interval PT5M` | 聚合粒度 |
| `-AgentName research-agent-stu07` | `--agent-name research-agent-stu07` | 指定 agent；預設由 `STUDENT_SUFFIX` 推導 |
| `-OutputPath ...` | `--output-path ...` | 輸出路徑；預設 `data/my-metrics.js` |

如果輸出為空，把腳本摘要交給 Copilot：

```text
這是 fetch-traces 的輸出。請判斷是沒有呼叫流量、Azure Monitor 攝入延遲、AgentName 過濾不匹配，還是 SP 權限問題；只給最小排查命令。
```

## 4.7 開啟本機 dashboard

**Windows（PowerShell）**

```powershell
start ..\Lab-4-observability\index.html
```

**macOS / Linux（bash）**

```bash
open ../Lab-4-observability/index.html      # Linux: xdg-open ../Lab-4-observability/index.html
```

頁面包含：

| 區域 | 說明 |
|------|------|
| KPI cards | 我的 responses、project tokens、tool calls、占比 |
| 我的 AgentResponses | 按 `AgentId` 過濾到自己的 hosted agent |
| Project Input/Output Tokens | project-wide 指標，目前 preview 不按學員拆分 |
| AgentResponses share | 同一 project 內各 agent 的 responses 分布 |
| Model Requests / Latency | account 級模型指標 |

解讀時可以問：

```text
這是 Lab 4 dashboard 的 KPI 和圖表文字。請分別說明哪些指標代表我的 agent，哪些是共享 project/account 級指標；如果 my_responses 小於剛才呼叫次數，給出可能原因。
```

完成後讓 Copilot 復盤：

```text
這是 data/my-metrics.js 中的 kpi 和 agents_share。請解釋我的 agent 是否產生了流量、project-wide tokens 是否可按學員拆分，以及 dashboard 是否達到 Lab 4 完成信號。
```

## 4.8 資料 schema

`data/my-metrics.js` 是一個可被 `file://` 頁面直接載入的腳本：

```js
window.__METRICS__ = {
  agent_name: "research-agent-stu07",
  generated_at: "2026-05-28T01:30:00Z",
  time_window_minutes: 60,
  interval: "PT5M",
  kpi: {
    my_total_responses: 3,
    project_input_tokens: 12000,
    project_output_tokens: 4000,
    project_total_tokens: 16000,
    project_tool_calls: 8,
    my_share_pct: 12.5
  },
  series: {
    my_responses: { timestamps: [], values: [] },
    project_in_tokens: { timestamps: [], values: [] },
    project_out_tokens: { timestamps: [], values: [] },
    project_tool_calls: { timestamps: [], values: [] },
    model_requests: { timestamps: [], values: [] },
    model_latency_ms: { timestamps: [], values: [] },
    tokens_per_second: { timestamps: [], values: [] }
  },
  agents_share: [{ agentId: "research-agent-stu07:1", total: 3 }]
};
```

## 4.9 關鍵概念

```text
Hosted /responses 呼叫
  │
  ├─ invoke-hosted.* 使用 FOUNDRY_API_KEY 調 agent endpoint
  │
  ▼
Foundry / Azure Monitor 指標
  ├─ AgentResponses          可按 AgentId 拆分
  ├─ AgentInputTokens        project-wide
  ├─ AgentOutputTokens       project-wide
  ├─ AgentToolCalls          project-wide
  ├─ ModelRequests           account-wide
  └─ TimeToResponse          account-wide
```

這不是逐條 conversation trace，而是課堂裡更穩定、權限更簡單的 operational metrics 路徑。`invoke-hosted.*` 仍會把 `response_id` 追加到 `data/responses.jsonl`，可作為加分挑戰擴充到逐條 response 詳情。

## 4.10 出口檢查點

- `fetch-traces.*` 寫出 `data/my-metrics.js`。
- `index.html` 不再顯示空狀態。
- KPI 中 `我的 AgentResponses` 大於 0。
- 能解釋哪些指標是自己的，哪些是共享 project/account 級指標。
- Copilot 能根據 dashboard 給出一個「是否可進入 wrap-up」的判斷。

## 4.11 故障速查

| 現象 | 處理 |
|------|------|
| `data/my-metrics.js` 不存在 | 先執行 `fetch-traces.*` |
| `my_responses=0` | 等 1-2 分鐘後重跑；確認 `STUDENT_SUFFIX` 和 agent 名稱一致 |
| 401 / token 取得失敗 | 檢查 `.env` 中 `AZURE_CLIENT_ID/SECRET/TENANT_ID` |
| metrics query 403 | SP 缺 Azure Monitor 讀權限或 project ID 不對；聯絡講師 |
| HTML 沒圖表 | 確認有網路載入 ECharts CDN；離線時需把 `echarts.min.js` 下載到本機並改 `index.html` |

## 4.12 加分挑戰

1. 讓 Copilot 把 `responses.jsonl` 中的 response id 拉成逐條 conversation 詳情視圖。
2. 讓 Copilot 在 `index.html` 增加 tool calls 時間序列圖，並解釋它改了哪些 DOM / chart option。
3. 讓 Copilot 把 `data/my-metrics.js` 改成多學員對比視圖，用於講師彙總。

→ [回到根 README 的 Wrap-up](../README.zh-TW.md#wrap-up--下一步)