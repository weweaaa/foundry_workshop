# Track A · 市场/竞品研究 Agent(默认场景)

工作坊**默认业务场景**。学员两条路径二选一:

- **A**:直接跑这套参考实现 → 部署到自己的 hosted agent。
- **B**:用本套架子换上自己的业务(参考 `personas/research-agent.md` + `tools/web_search.py` 的写法)。

## 架构

```
用户问题
   │
   ▼
[ResearchAgent]
   ├─ web_search   ← Bing / Google CSE / mock 自动回退
   ├─ web_fetch    ← httpx + 正文抽取
   └─ report_builder ← schema 校验 + 引用编号去重 + accessedAt 自动填
```

## 目录

```
Lab-2-vibe-coding/
├── personas/
│   ├── shared/guardrails.md           # 通用 guardrails(中性,调研向)
│   └── research-agent.md              # Soul:调研角色 + 输出契约
├── skills/
│   ├── market-research/SKILL.md       # 4 步流程:拆解→检索→整合→报告
│   └── citation-format/SKILL.md       # 引用与脚注规范
├── tools/                             # @tool (Python)
│   ├── web_search.py
│   ├── web_fetch.py
│   ├── report_builder.py
│   └── _shared/auth.py                # 通用凭据工厂(DefaultAzureCredential)
├── src/
│   ├── research_agent/
│   │   ├── main.py
│   │   ├── agent.yaml                 # hosted agent 部署元数据
│   │   ├── agent.manifest.yaml        # 运行时(模型 + server-side tools)
│   │   ├── Dockerfile                 # linux/amd64
│   │   └── requirements.txt
│   └── shared/                        # 通用 persona_loader / client_factory / skill_runner
├── tests/unit/test_tools.py
├── .github/                           # 工作坊私有 Copilot customization(VS Code 用)
│   ├── chatmodes/                     # maf-agent.chatmode.md
│   ├── instructions/                  # maf-{tools,personas,skills}.instructions.md
│   └── prompts/                       # persona / skill / tool / deploy.prompt.md (斜杠命令)
├── azure.yaml                         # 只声明 research-agent 一个 service
├── .env.example                       # 从讲师下发的凭据填写
├── .foundry/agent-metadata.yaml       # 评估占位
├── requirements.txt
└── README.md
```

## 本地跑通(Lab 2)

```powershell
# 1. 装依赖
pip install -r requirements.txt

# 2. 环境变量(从讲师下发的凭据复制到 .env)
Copy-Item .env.example .env
notepad .env       # 填 SP / endpoint / 模型 / 学员后缀

# 3. 加载 .env(PowerShell)
Get-Content .env | Where-Object { $_ -match '^\w' } | ForEach-Object {
  $k, $v = $_ -split '=', 2; [Environment]::SetEnvironmentVariable($k, $v, 'Process')
}

# 4. 启动
agentdev run src/research_agent/main.py --port 8087

# 5. 另一个终端发请求
$body = @{ input = "帮我研究'消费级 AI 笔记应用'品类,2025 重点对比 5 家" } | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "http://localhost:8087/responses" -ContentType "application/json" -Body $body
```

## 部署到 Foundry(Lab 3)

```powershell
azd env set AGENT_NAME       research-agent-$env:STUDENT_SUFFIX
azd env set AZURE_AI_PROJECT_ENDPOINT $env:AZURE_AI_PROJECT_ENDPOINT
azd env set AZURE_AI_MODEL_DEPLOYMENT_NAME $env:AZURE_AI_MODEL_DEPLOYMENT_NAME

azd deploy research-agent
..\scripts\invoke-hosted.ps1 -AgentName "research-agent-$env:STUDENT_SUFFIX" -Prompt "ping"
```

详见 [`../docs/../Lab-3-update-hosted-agent/README.md`](../docs/../Lab-3-update-hosted-agent/README.md)。

## 试试 mock 模式

无 `BING_SEARCH_API_KEY` / `GOOGLE_CSE_*` 时,`web_search` 自动走本地 mock;`WORKSHOP_WEB_FETCH_FORCE_MOCK=1` 强制 `web_fetch` 走 mock。两者一起开就能完全离线 vibe coding。

## Copilot 走法

VS Code 学员(默认):打开 `Lab-2-vibe-coding/`,Copilot Chat 顶部选 `maf-agent`,用 `/persona` `/skill` `/tool` `/deploy` 斜杠命令。

Copilot CLI 学员:复制 `.github/prompts/<name>.prompt.md` 模板内容,填好参数后用 `gh copilot suggest "<填好的 prompt>"`。

两种环境都能从 `.agents/skills/`(仓库根)下加载微软官方 skill 作为知识库:`microsoft-foundry`(部署 / 评估 / observability)、`agent-framework-azure-ai-py`(Python SDK)、`azure-ai-projects-py`(Foundry 项目 SDK)、`skill-creator`(创建 skill)。
