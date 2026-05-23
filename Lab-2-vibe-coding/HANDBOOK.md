# Lab 2 · GitHub Copilot + MAF vibe coding 业务 agent(55 min)

Lab 1 部署的是 Foundry 提供的 placeholder。本 Lab 在 Lab-2-vibe-coding 工作目录里**本地**写一个真正的业务 agent(默认:市场/竞品研究助手),Lab 3 再把它推回 hosted slot。

## 2.1 目标

- 熟悉 **Soul(Persona) · Skills · Tools** 三件套约定
- 用 Copilot 生成三件套骨架(VS Code 用斜杠命令,CLI 用 prompt 模板)
- `agentdev run` 本地跑通 → POST 返回业务 JSON
- 可选:把默认场景换成你自己的业务

## 2.2 配合 Copilot

| 任务 | VS Code 走法 | Copilot CLI 走法 |
|------|------------|------|
| 生成 / 改 persona | `/persona agentName=… role=… boundaries=…` | 复制 `Lab-2-vibe-coding/.github/prompts/persona.prompt.md` 的模板填好 → `gh copilot suggest "<填好的 prompt>"` |
| 生成 / 改 SKILL.md | `/skill skillName=… purpose=…` | 同上,用 `skill.prompt.md` |
| 生成 / 改 tool | `/tool toolName=… inputs=… outputs=…` | 同上,用 `tool.prompt.md` |
| 解释 trace | 截图给 Chat | `gh copilot explain "<粘 span 文本>"` |
| Agent Framework SDK 深入 | 关键词命中后自动加载 `.agents/skills/agent-framework-azure-ai-py/` | 拼上 `.agents/skills/agent-framework-azure-ai-py/SKILL.md` 作为 context |

## 2.3 默认场景:市场/竞品研究助手

讲师默认场景,Lab 2 直接用。看 [`../Lab-2-vibe-coding/personas/research-agent.md`](../Lab-2-vibe-coding/personas/research-agent.md) 与 [`../Lab-2-vibe-coding/skills/market-research/SKILL.md`](../Lab-2-vibe-coding/skills/market-research/SKILL.md)。

能力:

```
输入:一个产品 / 品类 / 公司
   │
   ▼
[ResearchAgent]
   ├─ 拆解 3-7 个子问题(不调任何工具)
   ├─ web_search   多关键词、多源
   ├─ web_fetch    抓正文 + 去 HTML
   ├─ report_builder  校验引用 + 输出结构化 JSON
   ▼
输出:带可点击脚注的 markdown 报告 + sources 数组 + confidence 评级
```

## 2.4 三件套 mini-milestones

### M1 · Persona / Soul(10 min)

**A. 默认场景** —— 已经写好,不用改。直接 lint:

**Windows（PowerShell）**

```powershell
python ..\scripts\lint-persona.py personas\research-agent.md
# ✅ persona research-agent OK · extends=[shared/guardrails.md] · version=1.0.0
```

**macOS / Linux（bash）**

```bash
python3 ../scripts/lint-persona.py personas/research-agent.md
# ✅ persona research-agent OK · extends=[shared/guardrails.md] · version=1.0.0
```

**B. 自带业务** —— 生成新 persona。

VS Code:

```
/persona agentName=invoice-explainer role="发票解读助手" boundaries="不查实时汇率;不给税务建议;必须从用户提供的发票文本里抽事实" tools="ocr_extract, classify_charges, currency_normalize" contract="{lineItems, totalsByCategory, suspiciousFlags}"
```

Copilot 会按 `.github/instructions/maf-personas.instructions.md` 的约定生成 `personas/invoice-explainer.md`。

Copilot CLI:

**Windows（PowerShell）**

```powershell
$prompt = @"
按 Lab-2-vibe-coding/.github/instructions/maf-personas.instructions.md 的约定,
生成 personas/invoice-explainer.md:

- 角色: 发票解读助手
- 边界:
  1. 不查实时汇率
  2. 不给税务建议
  3. 必须从用户提供的发票文本里抽事实
- 工具: ocr_extract, classify_charges, currency_normalize
- 输出契约: {lineItems, totalsByCategory, suspiciousFlags}

frontmatter 含 name: invoice-explainer, version: 1.0.0, owner: <team>, extends: shared/guardrails.md
body 顶部用 {{include: shared/guardrails.md}} inline 共享 guardrails
"@
gh copilot suggest $prompt
```

**macOS / Linux（bash）**

```bash
prompt=$(cat <<'EOF'
按 Lab-2-vibe-coding/.github/instructions/maf-personas.instructions.md 的约定，
生成 personas/invoice-explainer.md：

- 角色：发票解读助手
- 边界：
  1. 不查实时汇率
  2. 不给税务建议
  3. 必须从用户提供的发票文本里抽事实
- 工具：ocr_extract, classify_charges, currency_normalize
- 输出契约：{lineItems, totalsByCategory, suspiciousFlags}

frontmatter 含 name: invoice-explainer、version: 1.0.0、owner: <team>、extends: shared/guardrails.md
body 顶部用 {{include: shared/guardrails.md}} inline 共享 guardrails
EOF
)
gh copilot suggest "$prompt"
```

### M2 · Skill(10 min)

VS Code:

```
/skill skillName=invoice-explain purpose="一步步解读上传的发票"
triggers="用户上传图片或文本发票;用户问'每笔花在哪'"
tools="ocr_extract, classify_charges, currency_normalize"
relatedSkills="citation-format"
```

或者直接读 `skills/market-research/SKILL.md` 找灵感。

Copilot CLI:把 `Lab-2-vibe-coding/.github/prompts/skill.prompt.md` 内容复制到 prompt 起头,补具体字段,投喂给 `gh copilot suggest`。

### M3 · Client-side Tools(15 min)

VS Code:

```
/tool toolName=ocr_extract purpose="从图片或 PDF 抽文本"
inputs="image_url: HttpUrl, lang: str='auto'"
outputs="text: str, blocks: list[dict], pages: int"
liveBackend="Azure Computer Vision Read API (env: AZURE_VISION_KEY/AZURE_VISION_ENDPOINT)"
envKey="AZURE_VISION_KEY"
```

`.github/instructions/maf-tools.instructions.md` 会强制 pydantic + OTel + mock fallback。

Copilot CLI:同上,拼模板。

### M4 · 组装 + 本地跑通(15 min)

默认场景:`src/research_agent/main.py` 已写好。

自带业务参考写法:

```python
# src/my_agent/main.py
from agent_framework import Agent, SkillsProvider
from src.shared.client_factory import build_chat_client
from src.shared.persona import load_persona
from src.shared.skill_runner import run_local_skill_script
from pathlib import Path
import sys, os

_REPO = Path(__file__).resolve().parents[2]
if str(_REPO) not in sys.path:
    sys.path.insert(0, str(_REPO))

from tools.ocr_extract import ocr_extract
# ... 其它你新写的 tools

skills_provider = SkillsProvider.from_paths(
    skill_paths=[_REPO / "skills"],
    script_runner=run_local_skill_script,
)

agent = Agent(
    name=os.environ.get("AGENT_NAME", "invoice-explainer"),
    client=build_chat_client(),
    instructions=load_persona("invoice-explainer.md"),
    context_providers=[skills_provider],
    tools=[ocr_extract, classify_charges, currency_normalize],
    default_options={"store": False},
)
```

> 想了解 `AzureAIAgentsProvider` / hosted tools / streaming / MCP 等 Agent Framework Python SDK 细节,直接问 Copilot,关键词命中后会自动激活 `.agents/skills/agent-framework-azure-ai-py/`。

启动:

**Windows（PowerShell）**

```powershell
# 装依赖(只需一次)
pip install -r requirements.txt

# 加载 .env(讲师下发的凭据已经填进去)
Get-Content .env | Where-Object { $_ -match '^\w' } | ForEach-Object {
  $k, $v = $_ -split '=', 2; [Environment]::SetEnvironmentVariable($k, $v, 'Process')
}

# 启动(默认 8087)
agentdev run src\research_agent\main.py --port 8087
```

**macOS / Linux（bash）**

```bash
# 装依赖(只需一次)
pip install -r requirements.txt

# 加载 .env到当前 shell
set -a; source .env; set +a

# 启动(默认 8087)
agentdev run src/research_agent/main.py --port 8087
```

第二个终端:

**Windows（PowerShell）**

```powershell
$body = @{ input = "帮我研究'消费级 AI 笔记应用'品类,2025 重点对比 5 家" } | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "http://localhost:8087/responses" -ContentType "application/json" -Body $body
```

**macOS / Linux（bash）**

```bash
curl -s -X POST http://localhost:8087/responses \
  -H "Content-Type: application/json" \
  -d '{"input":"帮我研究\"消费级 AI 笔记应用\"品类，2025 重点对比 5 家"}' | jq .
```

应返回符合 `research-agent.md` 输出契约的 JSON(含 `report` + `sources` + `confidence`)。

### M5 · Agent Inspector + 用 Copilot 反思 trace(5 min)

**Windows（PowerShell）** 与 **macOS / Linux（bash）** 一致：

```
agentdev inspect
```

浏览器自动开。发一条**违反 guardrail 的 prompt**:

```
"X 公司值不值得投资?买入还是卖出?"
```

预期:persona 拒答(参考 `personas/shared/guardrails.md` 的"不做投资建议"规则)。Inspector 看到 chat span,返回 `{refused: true, ...}`。

选中 Inspector 里 `execute_tool: web_search` 那行,问 Copilot:

```
explain this span tree and why no web_fetch followed the search
```

(VS Code 学员粘到 Copilot Chat;CLI 学员用 `gh copilot explain "<span 文本>"`)

## 2.5 Copilot 使用心法

| 任务 | 最佳方式 |
|------|---------|
| 生成新 persona | `/persona` 斜杠 (VS Code) / `persona.prompt.md` 模板 (CLI) |
| 生成新 SKILL.md | `/skill` 斜杠 / `skill.prompt.md` 模板 |
| 生成新 @tool | `/tool` 斜杠 / `tool.prompt.md` 模板 |
| 解释 trace span | 截图 → Chat / `gh copilot explain` |
| 重构加超时/日志 | 选中代码 → `Ctrl+I` → `add 30s timeout and OTel span` |

详见 [`cheatsheet-copilot.md`](cheatsheet-copilot.md)。

## 2.6 出口检查点

✅ 三件套齐全:`personas/<agent>.md` + `skills/<skill>/SKILL.md` + `tools/<tool>.py`
✅ `lint-persona.py` 通过
✅ `agentdev run` 启动无错,本地 POST 返回业务 JSON
✅ Agent Inspector 看到 invoke_agent → execute_tool* → chat 序列

## 2.7 故障速查

| 现象 | 处理 |
|------|------|
| `FoundryChatClient` 401 | `az account get-access-token --resource https://ai.azure.com` 不行就 `azd auth login` 重登 |
| `agentdev run` 端口冲突 | `--port 8088` / `--port 8089` |
| Copilot 没按 instructions 走(例如生成 dict 而不是 pydantic) | 在 Chat 开头加上 `Use #file:.github/instructions/maf-tools.instructions.md` |
| 模型一直说"不知道工具",不调 `@tool` | 检查 `@tool(description=...)` 中文描述够不够具体 |
| Skill 文件没被加载 | 检查 `SkillsProvider.from_paths(skill_paths=[...])` 路径;SKILL.md 必须在子目录中 |

→ [Lab 3 · 把本地 agent 推到 hosted](../Lab-3-update-hosted-agent/README.md)
