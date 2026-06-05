# Lab 2 · GitHub Copilot + Agent Framework vibe coding（30 min）

Lab 1 已把仓库自带的 `research-agent` 发布到 Foundry。Lab 2 在本地迭代业务能力：先理解默认市场/竞品研究场景，再按需让 Copilot 生成或修改 persona、skill、tool。Lab 3 会重新发布这些修改。

## 2.1 目标

- 理解 **Soul / Persona · Skills · Tools** 三件套。
- 用 Copilot 生成或修改三件套。
- 本地 `agentdev run` 跑通 `/responses`。
- 可选：把默认研究助手替换成自己的业务 agent。

## 2.2 Agent-driven 工作方式

Lab 2 是整个 workshop 的 vibe coding 核心。不要让 Copilot 一口气“重写整个 agent”；把工作拆成 persona、skill、tool、local run、reflection 五个里程碑。每个里程碑都按同一个节奏走：

| 阶段 | 你做什么 | Copilot coding agent 做什么 |
|------|----------|------------------------------|
| Brief | 说明业务目标、不能做什么、输出要长什么样 | 复述目标，指出要看的文件 |
| Ask | 发 `/persona`、`/skill`、`/tool` 或 `@workspace` prompt | 生成或修改最小必要文件 |
| Inspect | 审 diff，判断是否符合业务常识 | 解释改动映射到 persona contract / tool schema |
| Verify | 运行 lint、unit test、`agentdev run`、HTTP POST | 总结结果，定位失败原因 |
| Reflect | 决定是否继续下一里程碑 | 给出下一步和 rollback 建议 |

通用起手 prompt：

```text
@workspace 我正在做 Lab 2。请先阅读 #file:Lab-2-vibe-coding/README.md、#file:personas/research-agent.md、#file:skills/market-research/SKILL.md、#file:tools/web_search.py 和 #file:src/research_agent/main.py。
本轮只做一个 mini-milestone。请告诉我：目标、相关文件、要运行的验证命令、完成信号。
```

## 2.3 配合 Copilot

| 任务 | VS Code 走法（主路径） | Copilot TUI 走法（可选） |
|------|--------------|------------------|
| 生成 / 改 persona | `/persona agentName=… role=… boundaries=…` | 运行 `copilot` 进入 chat，粘贴 `.github/prompts/persona.prompt.md` 模板和参数 |
| 生成 / 改 SKILL.md | `/skill skillName=… purpose=…` | 粘贴 `skill.prompt.md` 模板和参数 |
| 生成 / 改 tool | `/tool toolName=… inputs=… outputs=…` | 粘贴 `tool.prompt.md` 模板和参数 |
| 解释 SDK / hosted tools | 直接问 chat，关键词会命中 `.agents/skills/agent-framework-azure-ai-py/` | 把对应 `SKILL.md` 内容粘进 TUI chat |

## 2.4 默认场景：市场/竞品研究助手

```text
输入：一个产品 / 品类 / 公司
   │
   ▼
[ResearchAgent]
   ├─ 拆解 3-7 个子问题
   ├─ web_search       多关键词、多源检索
   ├─ web_fetch        抓正文 + 去 HTML
   └─ report_builder   校验引用 + 输出结构化 JSON
   ▼
输出：带脚注的 markdown 报告 + sources 数组 + confidence 评级
```

核心文件：

- `personas/research-agent.md`：角色、边界、输出契约。
- `personas/shared/guardrails.md`：共享拒答和安全边界。
- `skills/market-research/SKILL.md`：调研流程。
- `tools/*.py`：Agent Framework `@tool` 函数。
- `src/research_agent/main.py`：把 persona、skills、tools 组装成 agent。

## 2.5 代码目录速览

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

**Brief**：先确认 agent 的角色、拒答边界、工具使用规则和 JSON 输出契约。默认场景不要求改文件；自带业务才生成新 persona。

**Ask Copilot**：

```text
@workspace 检查 #file:personas/research-agent.md 和 #file:personas/shared/guardrails.md。
请说明这个 persona 的角色、拒答边界、工具调用顺序和输出契约；不要修改文件。
```

默认场景已写好，先 lint：

```powershell
python ..\scripts\lint-persona.py personas\research-agent.md
```

```bash
python3 ../scripts/lint-persona.py personas/research-agent.md
```

自带业务时，让 Copilot 生成新 persona，例如：

```text
/persona agentName=invoice-explainer role="发票解读助手" boundaries="不查实时汇率;不给税务建议;必须从用户提供的发票文本里抽事实" tools="ocr_extract, classify_charges, currency_normalize" contract="{lineItems, totalsByCategory, suspiciousFlags}"
```

**Inspect**：确认 frontmatter 有 `name`、`version`、`owner`、`extends`，正文引用 `{{include: shared/guardrails.md}}`，并且工具名与后续 tool 计划一致。

**Verify**：生成后再次运行 `lint-persona.py`。

**Reflect**：问 Copilot：

```text
请把 persona 的边界逐条映射到一个可测试 prompt，并指出哪些 prompt 应该拒答、哪些应该调用工具。
```

### M2 · Skill（5 min）

**Brief**：Skill 是流程说明书，不是代码。它要告诉模型“什么时候触发、按什么顺序做、失败时如何降级”。

**Ask Copilot**：

```text
@workspace 阅读 #file:skills/market-research/SKILL.md 和 #file:personas/research-agent.md。
请检查 skill 的步骤是否支持 persona 输出契约；如果发现矛盾，只提出最小修改建议。
```

默认场景读 `skills/market-research/SKILL.md`。自带业务可用：

```text
/skill skillName=invoice-explain purpose="一步步解读上传的发票" triggers="用户上传图片或文本发票;用户问每笔花在哪" tools="ocr_extract, classify_charges, currency_normalize" relatedSkills="citation-format"
```

**Inspect**：好的 `SKILL.md` 应该包含：触发条件、步骤、使用哪些 tool、失败/拒答边界。

**Verify**：让 Copilot 用 2 个成功 prompt 和 1 个拒答 prompt 走读流程，确认不会跳过必须的引用或 schema 检查。

**Reflect**：如果 skill 和 persona 目标不一致，优先改 skill；persona 只表达长期身份和边界。

### M3 · Client-side Tools（8 min）

**Brief**：Tool 是模型可调用的边界。课堂里 tool 必须可 mock、可测试、可观测；不要把外部 API 失败变成整条 Lab 卡死。

**Ask Copilot**：

```text
@workspace 参考 #file:tools/web_search.py、#file:tools/web_fetch.py、#file:tools/report_builder.py 和 #file:.github/instructions/maf-tools.instructions.md。
请检查现有 tool 的输入输出、mock fallback、timeout、OTel span 是否满足课堂要求。
```

默认 tool 已在 `tools/` 下。生成新 tool 时用：

```text
/tool toolName=ocr_extract purpose="从图片或 PDF 抽文本" inputs="image_url: HttpUrl, lang: str='auto'" outputs="text: str, blocks: list[dict], pages: int" liveBackend="Azure Computer Vision Read API" envKey="AZURE_VISION_KEY"
```

要求：

- 输入输出用 Pydantic 明确定义。
- `@tool(description=...)` 写清楚模型何时调用。
- 有 mock fallback，避免课堂网络或外部 API 阻塞。
- 加合理超时，不吞异常。

**Inspect**：确认新 tool 没有硬编码 key，异常路径返回可诊断错误，description 足够具体让模型知道何时调用。

**Verify**：

```powershell
pytest tests/unit/test_tools.py
```

如果只改了新 tool 且还没有 unit test，至少让 Copilot 生成一个 mock-path test，再运行相关测试。

**Reflect**：问 Copilot 哪些失败来自外部服务，哪些来自 schema / prompt 设计，避免把网络问题误判成 agent 逻辑问题。

### M4 · 本地组装 + 跑通（8 min）

**Brief**：把 persona、skills、tools 组装进 `src/research_agent/main.py`，本地用 `agentdev run` 验证完整 `/responses` 协议。

**Ask Copilot**：

```text
@workspace 解释 #file:src/research_agent/main.py 如何加载 persona、SkillsProvider 和 tools。
请告诉我如果换成自带业务 agent，最小需要改哪些 import、tool 列表和 persona 文件名。
```

**Windows（PowerShell）**

```powershell
cd Lab-2-vibe-coding
pip install -r requirements.txt
. ..\scripts\Windows\load-env.ps1
agentdev run src\research_agent\main.py --port 8087
```

另开终端：

```powershell
$body = @{ input = "帮我研究'消费级 AI 笔记应用'品类，2025 重点对比 5 家" } | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "http://localhost:8087/responses" -ContentType "application/json" -Body $body
```

**macOS / Linux（bash）**

```bash
cd Lab-2-vibe-coding
pip install -r requirements.txt
source ../scripts/macOSLinux/load-env.sh
agentdev run src/research_agent/main.py --port 8087
```

另开终端：

```bash
curl -s -X POST http://localhost:8087/responses \
  -H "Content-Type: application/json" \
  -d '{"input":"帮我研究\"消费级 AI 笔记应用\"品类，2025 重点对比 5 家"}' | jq .
```

预期返回符合 persona 输出契约的 JSON，至少包含 `report`、`sources`、`confidence`。

**Inspect**：如果返回能跑但结构不对，把响应贴给 Copilot，让它对照 `personas/research-agent.md` 找 contract 缺口。

**Verify**：成功样例之外，再跑一条拒答样例，确认 guardrail 没有被本地调试绕过。

### M5 · Inspector + 反思（4 min）

**Brief**：Inspector 不是看热闹的 UI，而是用来确认模型是否按 persona/skill/tool 约定行动。

```text
agentdev inspect
```

在浏览器里发一条应被拒答的问题：

```text
X 公司值不值得投资？买入还是卖出？
```

预期：persona 按 guardrail 拒绝投资建议。把 Inspector 中的 span 或截图交给 Copilot，让它解释为什么没有继续调用工具。

**Reflect prompt**：

```text
这是 Inspector 的 span / 截图文字。请说明：
1. 哪一步调用了模型
2. 哪些 tool 被调用或被跳过
3. 结果是否满足 persona contract
4. 进入 Lab 3 前还要修什么
```

## 2.7 自带业务的最小改法

1. 复制或生成 `personas/<agent>.md`。
2. 在 `skills/<skill>/SKILL.md` 描述业务流程。
3. 在 `tools/<tool>.py` 写 `@tool`。
4. 参考 `src/research_agent/main.py` 新建 `src/<agent>/main.py`。
5. 用 `/deploy` 生成对应 `agent.yaml` 和 `agent.manifest.yaml`。

不要直接硬编码 key；所有配置走 `.env` / 环境变量。

## 2.8 Mock 模式

没有 `BING_SEARCH_API_KEY` / `GOOGLE_CSE_*` 时，`web_search` 会自动回退到本地 mock；设置 `WORKSHOP_WEB_FETCH_FORCE_MOCK=1` 可强制 `web_fetch` 走 mock。两个都打开即可离线做 vibe coding。

让 Copilot 帮你确认离线路径：

```text
@workspace 检查 web_search 和 web_fetch 的 mock fallback。请告诉我在没有外部搜索 key 时，本地 Lab 2 是否还能完成端到端演示。
```

## 2.9 部署到 Foundry（Lab 3）

Lab 1 已经初始化并同步过 azd env。Lab 2 改完代码后只需：

```powershell
azd env set AGENT_NAME "research-agent-$env:STUDENT_SUFFIX"
azd deploy research-agent
..\scripts\Windows\invoke-hosted.ps1 -Prompt "ping"
```

```bash
azd env set AGENT_NAME "research-agent-${STUDENT_SUFFIX}"
azd deploy research-agent
../scripts/macOSLinux/invoke-hosted.sh --prompt "ping"
```

详见 [`../Lab-3-update-hosted-agent/README.md`](../Lab-3-update-hosted-agent/README.md)。

## 2.10 出口检查点

- persona lint 通过。
- `agentdev run` 启动无错。
- 本地 POST `/responses` 返回业务 JSON。
- 如果改了 tool，有相应 unit test 或至少一次本地 mock/live 调用验证。
- Copilot 能用一段话解释：本地版本和 Lab 1 hosted 版本相比，业务行为改变在哪里。

离开本目录前，请让 Copilot 总结一次：

```text
请总结我在 Lab 2 改了哪些 persona/skill/tool/runtime 文件，哪些验证已通过，以及 Lab 3 部署时最可能失败的 3 个点。
```

## 2.11 故障速查

| 现象 | 处理 |
|------|------|
| `FoundryChatClient` 401 | 确认已 `. ..\scripts\Windows\load-env.ps1` 或 `source ../scripts/macOSLinux/load-env.sh`；SP 需要在共享 project 上有 `Azure AI User` |
| `agentdev run` 端口冲突 | 改用 `--port 8088` |
| Copilot 生成内容不符合约定 | 在 prompt 中显式引用 `.github/instructions/maf-*.instructions.md` |
| 模型不调用 tool | 检查 `@tool(description=...)` 是否具体，输入 schema 是否清楚 |
| Skill 未加载 | `SKILL.md` 必须位于 `skills/<skill-name>/SKILL.md` |

→ [Lab 3 · 把本地 agent 推到 hosted](../Lab-3-update-hosted-agent/README.md)
