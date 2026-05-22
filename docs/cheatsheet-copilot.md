# 速查卡 · GitHub Copilot Chat / CLI 提示语

> 工作坊支持两种 Copilot 环境二选一:
> - **VS Code Copilot Chat**(默认推荐):打开 `Lab-2-vibe-coding/`,Lab 0 已经启用 chatmode / instructions / prompts;`.agents/skills/` 下的微软官方 skill 会按关键词自动激活。
> - **GitHub Copilot CLI**(终端环境):用 `gh copilot suggest` / `gh copilot explain`;手动把 SKILL.md 作为 context 喂给它。

## 入口与触发方式(VS Code)

| 入口 | 快捷键 | 适合 |
|------|--------|------|
| Copilot Chat 侧栏 | `Ctrl+Alt+I` | 跨文件提问、生成新文件 |
| Inline Chat | `Ctrl+I` | 在选中代码上做局部修改 |
| Quick Chat | `Ctrl+Shift+I` | 一次性短问 |
| `@workspace` 模式 | Chat 中 `@workspace …` | 让 Copilot 检索整个仓库 |
| `#file:` / `#selection` 引用 | Chat 中 `#file:path/to.md` | 把指定文件作为上下文 |
| Chat 模式下拉 | 顶部 | 选 `maf-agent` 切到工作坊 chatmode |

## 工作坊私有斜杠命令(VS Code 专属)

来自 `Lab-2-vibe-coding/.github/prompts/`,只在 VS Code Copilot Chat 中可用:

```
/persona  agentName=<name>      生成 Soul / 角色 markdown
/skill    skillName=<name>      生成 SKILL.md(流程说明书)
/tool     toolName=<name>       生成 @tool 函数(pydantic + OTel + mock 兜底)
/deploy   agentDir=<dir>        生成 agent.yaml + agent.manifest.yaml
```

每个 prompt 里 `${input:XYZ}` 是占位,Copilot 会按顺序问你填。

## 微软官方 skills(已装在 `.agents/skills/`,两种环境都能用)

| Skill | 何时自动激活 |
|------|--------|
| `microsoft-foundry` | "deploy agent / hosted agent / batch eval / prompt optimizer / 模型部署 / RBAC / quota / 区域 / 容量" 等关键词 |
| `agent-framework-azure-ai-py` | "AzureAIAgentsProvider / 持久 agent / hosted tools / function tools / streaming / MCP 集成" 等关键词 |
| `azure-ai-projects-py` | "AIProjectClient / PromptAgentDefinition / 评估 / 数据集 / 连接 / 部署" 等关键词 |
| `skill-creator` | "创建新 skill / 修订 SKILL.md / skill frontmatter" 等关键词 |

VS Code Copilot 在 chat 上下文里命中相关关键词时会自动注入 SKILL.md 摘要;需要完整内容时直接 `#file:.agents/skills/microsoft-foundry/SKILL.md`。

## Copilot CLI 走法

```bash
# 装(一次)
gh extension install github/gh-copilot

# 给一个具体任务建议命令
gh copilot suggest "deploy hosted agent to existing Foundry project, no provision"

# 解释一段命令
gh copilot explain "azd ai agent init -m src/research_agent/agent.manifest.yaml"
```

CLI 不会自动加载 `.agents/skills/`。需要 skill 知识时,把 SKILL.md 拼进 prompt:

```bash
# Windows pwsh
$ctx = Get-Content .agents\skills\microsoft-foundry\SKILL.md -Raw
gh copilot suggest "$ctx`n`n根据上面 skill 指南,执行: 用 azd 把 src/research_agent 部署成 hosted agent"

# macOS / Linux bash
ctx=$(cat .agents/skills/microsoft-foundry/SKILL.md)
gh copilot suggest "$ctx

根据上面 skill 指南, 执行: 用 azd 把 src/research_agent 部署成 hosted agent"
```

Lab 文档里 "VS Code 走法" 与 "Copilot CLI 走法" 二选一即可。VS Code 学员直接用斜杠命令;CLI 学员把对应斜杠命令的 prompt 内容(在 `Lab-2-vibe-coding/.github/prompts/*.prompt.md`)粘贴当 prompt 输入。

## 黄金模板(不用斜杠时)

### 生成 / 改 Persona

```text
@workspace 参考 #file:personas/shared/guardrails.md 与 #file:personas/research-agent.md,
生成 personas/<NEW>-agent.md:

- 角色:<一句话角色定义>
- 边界:
  1. <做什么>
  2. <不做什么>
  3. <红线>
- 工具:<逗号分隔>
- 输出契约(JSON schema 简述):<字段列表>

frontmatter 含 name: <name>, version: 1.0.0, owner: <team>, extends: shared/guardrails.md
body 顶部用 {{include: shared/guardrails.md}} inline 共享 guardrails
```

### 生成 / 改 Skill(workshop 内的 `skills/<skill-name>/SKILL.md`,不是 `.agents/skills/` 的官方 skill)

```text
@workspace 在 skills/<skill-name>/ 下生成 SKILL.md。

用途:<一句话>
触发条件:
  - <用户怎么说时调用>
工具:<@tool 函数名>
步骤:
  1. ...
  2. ...
  3. ...

末尾给出"边界"小节(何时不应该使用)。
```

### 生成 / 改 Tool

```text
@workspace 参考 #file:tools/web_search.py 与 #file:.github/instructions/maf-tools.instructions.md。

写 tools/<name>.py 的 @tool <fn>:
- 输入:<name>: <type>(中文描述)
- 输出:pydantic <Name>Result 含 <fields>
- 真实调用:<API + env key>
- mock 兜底:当 <ENV> 未设置或失败时
- 描述:<中文:何时调用>
```

### 生成 / 改 agent.yaml + agent.manifest.yaml

直接用 `/deploy`,或:

```text
@workspace 参考 #file:src/research_agent/agent.yaml 与 #file:src/research_agent/agent.manifest.yaml,
为 src/<my-agent>/main.py 生成两个 yaml。

要求:
- kind: hosted / host: azure.ai.agent / docker.remoteBuild: true
- resources: cpu 1 / memory 2Gi / scale 1-3
- env 注入: AZURE_AI_PROJECT_ENDPOINT / AZURE_AI_MODEL_DEPLOYMENT_NAME / AGENT_NAME / STUDENT_SUFFIX
- agent.manifest.yaml: instructions.file 指向 ../../personas/<agent>.md
- model: ${AZURE_AI_MODEL_DEPLOYMENT_NAME}(不要写死)
- tools: code_interpreter
```

## 反模式

| ❌ | ✅ |
|----|----|
| "帮我写个 agent" | "/persona agentName=X role=..." |
| "改一下这个" | "在 #file:src/research_agent/main.py 把 web_search 换成 web_fetch_v2,保留 SkillsProvider 参数不变" |
| 跨多文件改写不带 `#file:` | 总是用 `#file:` 引用所有相关文件作为上下文 |
| 让 Copilot 写 secret / hard-coded key | 在 prompt 强调 "env vars only, no hard-coded keys" |
| 一次问太多 | 拆 mini-milestone,每步只让它做一件事 |
| 把 Copilot 当编译器 | Copilot 不一定知道 Foundry 最新 preview API → 自己对照 `.agents/skills/microsoft-foundry/` 或官方 sample |

## Inline 重构常用语(选中代码 → `Ctrl+I`)

| 输入 | 用途 |
|------|------|
| `add 30s timeout` | 加超时 |
| `add OTel span via tracer, name "<x>"` | 加业务 span(Lab 4 用) |
| `add pydantic validation for inputs` | 加入参校验 |
| `extract into a helper function` | 抽函数 |
| `add docstring in Chinese, parameters & returns` | 加中文 docstring |
| `add a pytest unit test for this function` | 加测试 |

## 反查 trace 的提示语(Lab 4)

```text
这是一段 conversation span tree(来自 Lab-4-observability/index.html 或 my-traces.json):
1) 找出耗时最长的 span,并解释为什么
2) 哪个 tool 失败了?error_type 是什么?
3) 如果是 guardrail_refusal,对应 persona 的哪条边界?

<paste span list / screenshot>
```

## 出错时

- 生成内容不对 → "再试一次,把 `@tool` 的 description 写成具体的中文,模型按描述选工具"
- 生成代码不通 lint → 把 `#file:.github/instructions/maf-tools.instructions.md` 引用进上下文重生
- Persona 与 SKILL 互相矛盾 → "diff 给我两段,reconcile 后输出最终版本"
