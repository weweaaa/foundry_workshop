# GitHub Copilot + Microsoft Foundry Hosted Agent · 3h Hands-on Workshop

> 跟着 5 个 Lab，3 小时内从零搭一个**可部署、可观测**的 Foundry hosted agent，全程用 **GitHub Copilot** vibe coding。
> 学员不创建任何 Azure 资源；共享 Foundry account / project / 模型 / ACR 由讲师在配套仓库中预部署。
> 每位学员只把自己的 hosted agent（名字带 `STUDENT_SUFFIX`）推到这个共享 project，配额一锅端。

## 🚀 30 秒上手

```powershell
# 1. clone
git clone https://github.com/haxudev/foundry_workshop.git
cd foundry_workshop

# 2. 一次性填好凭据 (整个 workshop 共用这一份 .env)
cp .env.example .env
notepad .env      # 把讲师下发的 SP + endpoint + ACR 名填进去

# 3. 按 Lab 顺序往下走
code Lab-0-setup\README.md      # Lab 0: 环境 + Copilot + 登录
code Lab-1-deploy-hosted-agent\README.md
code Lab-2-vibe-coding\HANDBOOK.md
code Lab-3-update-hosted-agent\README.md
code Lab-4-observability\HANDBOOK.md
```

学员只需要 `.env` 一份，所有脚本（`scripts/chat-hosted.ps1`、`scripts/invoke-hosted.ps1`、`scripts/sanity-check.ps1`、`Lab-4-observability/fetch-traces.ps1`）都从仓库根 `.env` 自动读凭据，**不依赖 `az login` 或 `azd auth`**（脚本内部走 OAuth2 client_credentials grant 拿 token）。

## 🗺️ 目录结构

```
foundry_workshop/
├── README.md                              # ← 你正在看
├── .env.example                           # 一次性填，整个 workshop 用
│
├── scripts/                               # 跨 Lab 共享脚本
│   ├── load-env.ps1                       # 把 .env 加载进 PS process
│   ├── sanity-check.ps1                   # 验证 .env + 凭据 + 共享 Foundry 资源
│   ├── chat-hosted.ps1                    # 浏览器图形化跟 hosted agent 聊天 (Lab 1/3)
│   ├── chat-hosted/index.html             #   ↑ 单文件 chat UI
│   ├── invoke-hosted.ps1                  # 命令行单次 POST /responses (CI/脚本用)
│   ├── install-maf-copilot-skills.ps1     # Lab 0: 启用 VS Code Copilot customization
│   └── lint-persona.py                    # Lab 2: 校验 persona frontmatter
│
├── Lab-0-setup/                           # 环境 + Copilot + 凭据登录
│   └── README.md
├── Lab-1-deploy-hosted-agent/             # 部 placeholder hosted agent
│   └── README.md
├── Lab-2-vibe-coding/                     # 本地业务 agent (主代码栈)
│   ├── README.md                          # 代码目录索引
│   ├── HANDBOOK.md                        # Lab 2 教学手册
│   ├── azure.yaml                         # 学员从这跑 azd deploy
│   ├── .env.example -> ../.env.example
│   ├── personas/                          # Soul
│   │   ├── research-agent.md
│   │   └── shared/guardrails.md
│   ├── skills/                            # SKILL.md (业务流程)
│   │   ├── market-research/SKILL.md
│   │   └── citation-format/SKILL.md
│   ├── tools/                             # @tool 函数 (DuckDuckGo/Jina, 免 key)
│   │   ├── web_search.py
│   │   ├── web_fetch.py
│   │   └── report_builder.py
│   ├── src/
│   │   ├── research_agent/
│   │   │   ├── main.py
│   │   │   ├── agent.yaml                 # Foundry ContainerAgent v1.0 schema
│   │   │   ├── agent.manifest.yaml
│   │   │   ├── Dockerfile
│   │   │   └── requirements.txt           # 容器侧 (slim)
│   │   └── shared/                        # client_factory / persona / skill_runner
│   ├── tests/unit/                        # tool 单测
│   ├── requirements.txt                   # 本地 dev 全集
│   ├── pyproject.toml
│   └── .github/                           # 工作坊私有 Copilot customization
│       ├── chatmodes/maf-agent.chatmode.md
│       ├── instructions/maf-*.instructions.md
│       └── prompts/{persona,skill,tool,deploy}.prompt.md
├── Lab-3-update-hosted-agent/             # 把 Lab-2 业务推到 hosted slot
│   └── README.md                          # 引用 Lab-2 代码; azd deploy
├── Lab-4-observability/                   # 本地 HTML 看 trace
│   ├── README.md
│   ├── HANDBOOK.md
│   ├── index.html
│   ├── fetch-traces.ps1
│   └── data/traces.sample.json
│
├── docs/                                  # 跨 Lab 速查 / 总览
│   ├── 00-intro.md
│   ├── 99-wrap-up.md
│   ├── cheatsheet-copilot.md
│   ├── cheatsheet-foundry-api.md
│   └── cheatsheet-powershell.md
│
├── .agents/skills/                        # 微软官方 skills (VS Code Copilot 自动加载)
└── backup/                                # 设计文档归档
```

## 🎯 学完你能做到

1. 用 `azd deploy` 把一个 Foundry hosted agent 部署到共享 project（占位 → 自己业务两阶段）
2. 用 GitHub Copilot（VS Code Chat 或 Copilot CLI 二选一）+ 仓库自带的 skill 套件写出 **Soul + Skills + Tools** 三件套，本地直接 `python -m src.research_agent.main` 跑通
3. 把本地业务 agent 增量推回 hosted slot，hosted endpoint 200 OK
4. **不登 Azure Portal、也不需要 az CLI**：用 `scripts/chat-hosted.ps1` 浏览器多轮聊；用 `Lab-4-observability/fetch-traces.ps1` + 本地 HTML 看 trace

## 🛠️ Copilot 双环境兼容

| 环境 | 配置 | 入口 |
|------|------|------|
| VS Code Copilot Chat | Lab 0 跑 `scripts\install-maf-copilot-skills.ps1` 启用 `Lab-2-vibe-coding/.github/{chatmodes,instructions,prompts}/` | `Ctrl+Alt+I` 选 `maf-agent` chatmode + 斜杠命令 `/persona` `/skill` `/tool` `/deploy` |
| GitHub Copilot CLI | `gh extension install github/gh-copilot` | `gh copilot suggest "<prompt>"` / `gh copilot explain "<command>"` |

两种环境都能用仓库根 `.agents/skills/` 下的 4 个微软官方 skill 作为知识库：

- `microsoft-foundry` — Foundry hosted agent 部署 / 评估 / observability / RBAC / 配额
- `agent-framework-azure-ai-py` — Agent Framework Python SDK
- `azure-ai-projects-py` — Azure AI Projects Python SDK (高层 Foundry SDK)
- `skill-creator` — 创建 / 修订自定义 skill

## 🗓️ 时长结构 (180 min)

| # | 段落 | 时长 | 出口产物 |
|---|------|------|---------|
| 0 | [开场 · 架构总览](docs/00-intro.md) | 10 min | 选默认场景 / 自带业务 |
| 1 | [Lab 0 · 环境补齐 + 凭据登录 + Copilot skills](Lab-0-setup/README.md) | 20 min | `.env` 填好，`sanity-check.ps1` 全 ✅ |
| 2 | [Lab 1 · 部署你的第一个 hosted agent](Lab-1-deploy-hosted-agent/README.md) | 30 min | hosted endpoint 200 OK，拿到预览 URL |
| 3 | ☕ Buffer | 5 min | — |
| 4 | [Lab 2 · GitHub Copilot vibe coding 业务 agent](Lab-2-vibe-coding/HANDBOOK.md) | 55 min | 本地 agent 返回业务 JSON |
| 5 | [Lab 3 · 把本地 agent 推到 hosted](Lab-3-update-hosted-agent/README.md) | 25 min | hosted endpoint 返回业务 JSON |
| 6 | [Lab 4 · 本地 HTML 看 Foundry tracing](Lab-4-observability/HANDBOOK.md) | 25 min | 本地 HTML 看到自己的 conversation 时间线 |
| 7 | [Wrap-up](docs/99-wrap-up.md) | 10 min | 下一步资料 |

## 🆘 卡住了怎么办

- 每个 Lab 都有出口检查脚本：`scripts\sanity-check.ps1` 全 ✅ 才继续
- 助教巡场，白板上贴 `#help-lab-N` 即可
- 极端兜底：`Lab-4-observability/data/traces.sample.json` 是讲师 demo，HTML 默认就显示它

## 📋 速查卡

- [PowerShell 转义速查](docs/cheatsheet-powershell.md)
- [GitHub Copilot Chat / CLI 提示语速查](docs/cheatsheet-copilot.md)
- [Foundry agents 数据平面 API 速查](docs/cheatsheet-foundry-api.md)

## ⚠️ 共享 Foundry 的约定

- 所有 hosted agent **共用一个 model deployment**（讲师指定，默认 `gpt-5.5`）。配额是大家共享的 ≈ 50K TPM，请不要做 stress test。
- 每位学员 hosted agent 后缀 `STUDENT_SUFFIX`（讲师分配，如 `stu07`）。**只动自己后缀的资源**：不删别人 agent、不改 shared ACR 配置。
- 共享 ACR 学员有 `AcrPush + Contributor` 角色；hosted agent 拉镜像走 project MI 的 `AcrPull`，不影响别人。
- 观测：不需要 Azure Portal / App Insights / SWA；本地 HTML + Foundry tracing API 即可。
