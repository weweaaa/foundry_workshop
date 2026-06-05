# Lab 2 · GitHub Copilot + Agent Framework vibe coding（30 min）

Lab 1 已把倉庫內建的 `research-agent` 發布到 Foundry。Lab 2 在本機迭代業務能力：先理解預設市場/競品研究場景，再按需讓 Copilot 產生或修改 persona、skill、tool。Lab 3 會重新發布這些修改。

## 2.1 目標

- 理解 **Soul / Persona · Skills · Tools** 三件套。
- 用 Copilot 產生或修改三件套。
- 本機 `agentdev run` 跑通 `/responses`。
- 可選：把預設研究助手替換成自己的業務 agent。

## 2.2 Agent-driven 工作方式

Lab 2 是整個 workshop 的 vibe coding 核心。不要讓 Copilot 一口氣「重寫整個 agent」；把工作拆成 persona、skill、tool、local run、reflection 五個里程碑。每個里程碑都按同一個節奏走：

| 階段 | 你做什麼 | Copilot coding agent 做什麼 |
|------|----------|------------------------------|
| Brief | 說明業務目標、不能做什麼、輸出要長什麼樣 | 複述目標，指出要看的檔案 |
| Ask | 發 `/persona`、`/skill`、`/tool` 或 `@workspace` prompt | 產生或修改最小必要檔案 |
| Inspect | 審 diff，判斷是否符合業務常識 | 解釋修改如何映射到 persona contract / tool schema |
| Verify | 執行 lint、unit test、`agentdev run`、HTTP POST | 總結結果，定位失敗原因 |
| Reflect | 決定是否進入下一個里程碑 | 給出下一步和 rollback 建議 |

通用起手 prompt：

```text
@workspace 我正在做 Lab 2。請先閱讀 #file:Lab-2-vibe-coding/README.md、#file:personas/research-agent.md、#file:skills/market-research/SKILL.md、#file:tools/web_search.py 和 #file:src/research_agent/main.py。
本輪只做一個 mini-milestone。請告訴我：目標、相關檔案、要執行的驗證命令、完成信號。
```

## 2.3 配合 Copilot

| 任務 | VS Code 走法（主路徑） | Copilot TUI 走法（可選） |
|------|--------------|------------------|
| 產生 / 改 persona | `/persona agentName=… role=… boundaries=…` | 執行 `copilot` 進入 chat，貼上 `.github/prompts/persona.prompt.md` 模板和參數 |
| 產生 / 改 SKILL.md | `/skill skillName=… purpose=…` | 貼上 `skill.prompt.md` 模板和參數 |
| 產生 / 改 tool | `/tool toolName=… inputs=… outputs=…` | 貼上 `tool.prompt.md` 模板和參數 |
| 解釋 SDK / hosted tools | 直接問 chat，關鍵詞會命中 `.agents/skills/agent-framework-azure-ai-py/` | 把對應 `SKILL.md` 內容貼進 TUI chat |

## 2.4 預設場景：市場/競品研究助手

```text
輸入：一個產品 / 品類 / 公司
   │
   ▼
[ResearchAgent]
   ├─ 拆解 3-7 個子問題
   ├─ web_search       多關鍵詞、多來源檢索
   ├─ web_fetch        抓正文 + 去 HTML
   └─ report_builder   校驗引用 + 輸出結構化 JSON
   ▼
輸出：帶腳註的 markdown 報告 + sources 陣列 + confidence 評級
```

核心檔案：

- `personas/research-agent.md`：角色、邊界、輸出契約。
- `personas/shared/guardrails.md`：共享拒答與安全邊界。
- `skills/market-research/SKILL.md`：研究流程。
- `tools/*.py`：Agent Framework `@tool` 函式。
- `src/research_agent/main.py`：把 persona、skills、tools 組裝成 agent。

## 2.5 程式碼目錄速覽

```text
Lab-2-vibe-coding/
├── azure.yaml                         # azd deploy 入口
├── hooks/postdeploy-grant-roles.ps1   # azd postdeploy wrapper
├── personas/
│   ├── shared/guardrails.md
│   └── research-agent.md
├── skills/
│   ├── market-research/SKILL.md
│   └── citation-format/SKILL.md
├── tools/
│   ├── web_search.py
│   ├── web_fetch.py
│   └── report_builder.py
├── src/research_agent/
│   ├── main.py
│   ├── agent.yaml.tpl
│   ├── agent.manifest.yaml.tpl
│   ├── Dockerfile
│   └── requirements.txt
├── tests/unit/
├── .github/                           # VS Code Copilot customization
├── requirements.txt
└── pyproject.toml
```

## 2.6 Mini-milestones

### M1 · Persona / Soul（5 min）

**Brief**：先確認 agent 的角色、拒答邊界、工具使用規則和 JSON 輸出契約。預設場景不要求改檔案；自帶業務才產生新 persona。

**Ask Copilot**：

```text
@workspace 檢查 #file:personas/research-agent.md 和 #file:personas/shared/guardrails.md。
請說明這個 persona 的角色、拒答邊界、工具呼叫順序和輸出契約；不要修改檔案。
```

預設場景已寫好，先 lint：

```powershell
python ..\scripts\lint-persona.py personas\research-agent.md
```

```bash
python3 ../scripts/lint-persona.py personas/research-agent.md
```

自帶業務時，讓 Copilot 產生新 persona，例如：

```text
/persona agentName=invoice-explainer role="發票解讀助手" boundaries="不查即時匯率;不給稅務建議;必須從使用者提供的發票文本抽取事實" tools="ocr_extract, classify_charges, currency_normalize" contract="{lineItems, totalsByCategory, suspiciousFlags}"
```

**Inspect**：確認 frontmatter 有 `name`、`version`、`owner`、`extends`，正文引用 `{{include: shared/guardrails.md}}`，且工具名與後續 tool 計畫一致。

**Verify**：產生後再次執行 `lint-persona.py`。

**Reflect**：問 Copilot：

```text
請把 persona 的邊界逐條映射到一個可測試 prompt，並指出哪些 prompt 應該拒答、哪些應該呼叫工具。
```

### M2 · Skill（5 min）

**Brief**：Skill 是流程說明書，不是程式碼。它要告訴模型「什麼時候觸發、按什麼順序做、失敗時如何降級」。

**Ask Copilot**：

```text
@workspace 閱讀 #file:skills/market-research/SKILL.md 和 #file:personas/research-agent.md。
請檢查 skill 的步驟是否支援 persona 輸出契約；如果發現矛盾，只提出最小修改建議。
```

預設場景讀 `skills/market-research/SKILL.md`。自帶業務可用：

```text
/skill skillName=invoice-explain purpose="一步步解讀上傳的發票" triggers="使用者上傳圖片或文字發票;使用者問每筆花在哪" tools="ocr_extract, classify_charges, currency_normalize" relatedSkills="citation-format"
```

**Inspect**：好的 `SKILL.md` 應該包含：觸發條件、步驟、使用哪些 tool、失敗/拒答邊界。

**Verify**：讓 Copilot 用 2 個成功 prompt 和 1 個拒答 prompt 走讀流程，確認不會跳過必要引用或 schema 檢查。

**Reflect**：如果 skill 和 persona 目標不一致，優先改 skill；persona 只表達長期身份和邊界。

### M3 · Client-side Tools（8 min）

**Brief**：Tool 是模型可呼叫的邊界。課堂裡 tool 必須可 mock、可測試、可觀測；不要把外部 API 失敗變成整條 Lab 卡死。

**Ask Copilot**：

```text
@workspace 參考 #file:tools/web_search.py、#file:tools/web_fetch.py、#file:tools/report_builder.py 和 #file:.github/instructions/maf-tools.instructions.md。
請檢查現有 tool 的輸入輸出、mock fallback、timeout、OTel span 是否滿足課堂要求。
```

預設 tool 已在 `tools/` 下。產生新 tool 時用：

```text
/tool toolName=ocr_extract purpose="從圖片或 PDF 抽文本" inputs="image_url: HttpUrl, lang: str='auto'" outputs="text: str, blocks: list[dict], pages: int" liveBackend="Azure Computer Vision Read API" envKey="AZURE_VISION_KEY"
```

要求：

- 輸入輸出用 Pydantic 明確定義。
- `@tool(description=...)` 寫清楚模型何時呼叫。
- 有 mock fallback，避免課堂網路或外部 API 阻塞。
- 加合理 timeout，不吞例外。

**Inspect**：確認新 tool 沒有硬編碼 key，例外路徑返回可診斷錯誤，description 足夠具體讓模型知道何時呼叫。

**Verify**：

```powershell
pytest tests/unit/test_tools.py
```

如果只改了新 tool 且還沒有 unit test，至少讓 Copilot 產生一個 mock-path test，再執行相關測試。

**Reflect**：問 Copilot 哪些失敗來自外部服務，哪些來自 schema / prompt 設計，避免把網路問題誤判成 agent 邏輯問題。

### M4 · 本機組裝 + 跑通（8 min）

**Brief**：把 persona、skills、tools 組裝進 `src/research_agent/main.py`，本機用 `agentdev run` 驗證完整 `/responses` 協議。

**Ask Copilot**：

```text
@workspace 解釋 #file:src/research_agent/main.py 如何載入 persona、SkillsProvider 和 tools。
請告訴我如果換成自帶業務 agent，最小需要改哪些 import、tool 列表和 persona 檔名。
```

**Windows（PowerShell）**

```powershell
cd Lab-2-vibe-coding
pip install -r requirements.txt
. ..\scripts\Windows\load-env.ps1
agentdev run src\research_agent\main.py --port 8087
```

另開終端：

```powershell
$body = @{ input = "幫我研究'消費級 AI 筆記應用'品類，2025 重點對比 5 家" } | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "http://localhost:8087/responses" -ContentType "application/json" -Body $body
```

**macOS / Linux（bash）**

```bash
cd Lab-2-vibe-coding
pip install -r requirements.txt
source ../scripts/macOSLinux/load-env.sh
agentdev run src/research_agent/main.py --port 8087
```

另開終端：

```bash
curl -s -X POST http://localhost:8087/responses \
  -H "Content-Type: application/json" \
  -d '{"input":"幫我研究\"消費級 AI 筆記應用\"品類，2025 重點對比 5 家"}' | jq .
```

預期返回符合 persona 輸出契約的 JSON，至少包含 `report`、`sources`、`confidence`。

**Inspect**：如果返回能跑但結構不對，把回應貼給 Copilot，讓它對照 `personas/research-agent.md` 找 contract 缺口。

**Verify**：成功樣例之外，再跑一條拒答樣例，確認 guardrail 沒有被本機除錯繞過。

### M5 · Inspector + 反思（4 min）

**Brief**：Inspector 不是看熱鬧的 UI，而是用來確認模型是否按 persona/skill/tool 約定行動。

```text
agentdev inspect
```

在瀏覽器裡發一條應被拒答的問題：

```text
X 公司值不值得投資？買入還是賣出？
```

預期：persona 按 guardrail 拒絕投資建議。把 Inspector 中的 span 或截圖交給 Copilot，讓它解釋為什麼沒有繼續呼叫工具。

**Reflect prompt**：

```text
這是 Inspector 的 span / 截圖文字。請說明：
1. 哪一步呼叫了模型
2. 哪些 tool 被呼叫或被跳過
3. 結果是否滿足 persona contract
4. 進入 Lab 3 前還要修什麼
```

## 2.7 Mock 模式

沒有 `BING_SEARCH_API_KEY` / `GOOGLE_CSE_*` 時，`web_search` 會自動回退到本機 mock；設定 `WORKSHOP_WEB_FETCH_FORCE_MOCK=1` 可強制 `web_fetch` 走 mock。兩個都打開即可離線做 vibe coding。

讓 Copilot 幫你確認離線路徑：

```text
@workspace 檢查 web_search 和 web_fetch 的 mock fallback。請告訴我在沒有外部搜尋 key 時，本機 Lab 2 是否還能完成端到端演示。
```

## 2.8 自帶業務的最小改法

1. 複製或產生 `personas/<agent>.md`。
2. 在 `skills/<skill>/SKILL.md` 描述業務流程。
3. 在 `tools/<tool>.py` 寫 `@tool`。
4. 參考 `src/research_agent/main.py` 新建 `src/<agent>/main.py`。
5. 用 `/deploy` 產生對應 `agent.yaml` 和 `agent.manifest.yaml`。

不要直接硬編碼 key；所有設定走 `.env` / 環境變數。

## 2.9 部署到 Foundry（Lab 3）

Lab 1 已經初始化並同步過 azd env。Lab 2 改完程式後只需：

**Windows（PowerShell）**

```powershell
azd env set AGENT_NAME "research-agent-$env:STUDENT_SUFFIX"
azd deploy research-agent
..\scripts\Windows\invoke-hosted.ps1 -Prompt "ping"
```

**macOS / Linux（bash）**

```bash
azd env set AGENT_NAME "research-agent-${STUDENT_SUFFIX}"
azd deploy research-agent
../scripts/macOSLinux/invoke-hosted.sh --prompt "ping"
```

詳見 [`../Lab-3-update-hosted-agent/README.zh-TW.md`](../Lab-3-update-hosted-agent/README.zh-TW.md)。

## 2.10 出口檢查點

- persona lint 通過。
- `agentdev run` 啟動無錯。
- 本機 POST `/responses` 返回業務 JSON。
- 如果改了 tool，有相應 unit test 或至少一次本機 mock/live 呼叫驗證。
- Copilot 能用一段話解釋：本機版本和 Lab 1 hosted 版本相比，業務行為改變在哪裡。

## 2.11 故障速查

| 現象 | 處理 |
|------|------|
| `FoundryChatClient` 401 | 確認已 `. ..\scripts\Windows\load-env.ps1` 或 `source ../scripts/macOSLinux/load-env.sh`；SP 需要在共享 project 上有 `Azure AI User` |
| `agentdev run` 連接埠衝突 | 改用 `--port 8088` |
| Copilot 產生內容不符合約定 | 在 prompt 中顯式引用 `.github/instructions/maf-*.instructions.md` |
| 模型不呼叫 tool | 檢查 `@tool(description=...)` 是否具體，輸入 schema 是否清楚 |
| Skill 未載入 | `SKILL.md` 必須位於 `skills/<skill-name>/SKILL.md` |

離開本目錄前，請讓 Copilot 總結一次：

```text
請總結我在 Lab 2 改了哪些 persona/skill/tool/runtime 檔案，哪些驗證已通過，以及 Lab 3 部署時最可能失敗的 3 個點。
```

→ [Lab 3 · 把本機 agent 推到 hosted](../Lab-3-update-hosted-agent/README.zh-TW.md)
