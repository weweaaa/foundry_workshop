# 0 · 开场:架构总览 + 选轨(10 min)

## 0.1 为什么需要 agent harness

一个能上生产的 agent 不是"写个 prompt + 接个模型"那么简单。它需要:

- **Soul**:角色边界、口吻、拒绝策略 → `personas/*.md`
- **Skills**:完成任务的步骤说明书 → `skills/<skill>/SKILL.md`
- **Tools**:调外部 API / 写状态的函数 → `tools/*.py`(`@tool`)
- **Runtime**:模型 + 容器 + 路由 → Microsoft Foundry Hosted Agent

`harness` 把这些按目录约定组织起来,可版本化、可评估、可观测。

## 0.2 三层架构

```
┌─────────────────────────────────────────────────────────────┐
│  L3 应用层    Hosted Agent 容器 = MAF Agent                │  ← Lab 2/3 主战场
│              ├── instructions ← personas/*.md   (Soul)     │
│              ├── context_providers=[SkillsProvider]        │
│              ├── tools=[client-side @tool …]              │
│              └── client = FoundryChatClient (.foundry)     │
├─────────────────────────────────────────────────────────────┤
│  L2 模型与工具层  Foundry server-side tools                │  ← Lab 1/3 涉及
│                  + Foundry Model Deployments               │     (讲师事前预部署)
├─────────────────────────────────────────────────────────────┤
│  L1 共享基础设施  Foundry account / project / 模型 / ACR  │  ← 学员不动
│                  (讲师在另一仓库中预部署并下发凭据)        │
└─────────────────────────────────────────────────────────────┘

观测:本地 HTML + Foundry agents 数据平面 API(不走 portal、不走 App Insights)
```

> 共享 Foundry 资源由讲师在配套仓库中预部署。学员配额一锅端,每位学员只部署自己的 hosted agent(名字带 `STUDENT_SUFFIX`,如 `research-agent-stu07`)到同一个 project。

## 0.3 默认场景:市场/竞品研究助手

```
用户问题(产品 / 品类 / 公司)
   │
   ▼
[ResearchAgent]
   ├─ 拆解 3-7 个子问题
   ├─ web_search    多源检索(Bing / Google CSE / mock)
   ├─ web_fetch     抓正文 + 去 HTML
   └─ report_builder 校验引用 + 结构化输出
```

为什么选这个场景?三个理由:

1. **能现场演示**:web search / fetch 工具成熟,公开数据,不卡内网;
2. **每位学员看到不一样的结果**:自带的产品/品类有差异,trace 各不相同;
3. **强约束输出契约**:必须带引用、多源、`confidence` 评级 —— 教会学员"persona 是有契约的"。

## 0.4 选路径

| 你是谁 | 推荐路径 |
|--------|---------|
| "先把流程走通" | **A · 默认调研场景**(直接用 `Lab-2-vibe-coding/`) |
| "我想换业务" | **B · 自带业务**(用 `/persona`、`/tool`、`/skill` 斜杠命令让 Copilot 复制 `Lab-2-vibe-coding` 骨架) |

不论 A/B,Lab 1(部署 placeholder)→ Lab 2(本地 vibe coding)→ Lab 3(部署本地业务 agent)→ Lab 4(观测)流程一致。

## 0.5 GitHub Copilot 在本工作坊的角色

学员可二选一:

### 选项 A · VS Code Copilot Chat(默认推荐)

Lab 0 跑 `install-maf-copilot-skills.ps1` 会启用 `Lab-2-vibe-coding/.github/` 下的工作坊私有 customization:

| 类型 | 文件 | 作用 |
|------|------|------|
| chatmode | `.github/chatmodes/maf-agent.chatmode.md` | 全局上下文(约定 / 偏好 / 历史踩坑) |
| instructions | `.github/instructions/maf-{tools,personas,skills}.instructions.md` | 按文件类型自动注入约束 |
| prompts | `.github/prompts/{persona,skill,tool,deploy}.prompt.md` | `/persona` `/skill` `/tool` `/deploy` 斜杠命令 |

同时仓库根 `.agents/skills/` 已装好 4 个微软官方 skill,VS Code Copilot 会按关键词**自动激活**:

| Skill | 何时被激活 |
|------|---------|
| `microsoft-foundry` | "deploy / hosted agent / batch eval / 模型部署 / RBAC / quota / 区域" 等 |
| `agent-framework-azure-ai-py` | "AzureAIAgentsProvider / hosted tools / function tools / streaming / MCP" 等 |
| `azure-ai-projects-py` | "AIProjectClient / PromptAgentDefinition / 评估 / 连接 / 数据集" 等 |
| `skill-creator` | "创建 skill / 修订 SKILL.md / frontmatter" 等 |

### 选项 B · GitHub Copilot CLI

终端环境,用 `gh copilot suggest` / `gh copilot explain`。CLI 不会自动加载 `.agents/skills/`,需要 skill 知识时把对应 SKILL.md 内容拼进 prompt。每个 Lab 都会列出 "VS Code 走法 / Copilot CLI 走法" 二选一,以及对应的 prompt 模板。

详细使用细节见 [`cheatsheet-copilot.md`](cheatsheet-copilot.md)。

### 各 Lab 中 Copilot 主要负责什么

| Lab | Copilot 任务 |
|------|------------|
| Lab 1 | 看懂 azure.yaml 为什么"无 infra";用 `/deploy` 写部署 yaml |
| Lab 2 | `/persona` `/skill` `/tool` 生成三件套;解释 trace |
| Lab 3 | `/deploy` 生成 hosted agent yaml |
| Lab 4 | 解释 span / 扩展自定义 attribute |

口诀:**Copilot 是手,你是脑**。指令越具体、上下文越足(`#file:`),生成质量越高。

→ [Lab 0 · 本地环境 + Copilot + 凭据登录](../Lab-0-setup/README.md)
