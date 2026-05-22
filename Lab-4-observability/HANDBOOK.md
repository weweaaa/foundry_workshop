# Lab 4 · 本地 HTML + Foundry tracing API 看自己的 agent(25 min)

学员凭自己的 SP token 直接拉 Foundry agents 数据平面 API 的 threads/runs/steps,规范化成 spans-like JSON,让本地单文件 HTML 渲染。不登 portal、不依赖 Application Insights。

## 4.1 目标

- 用 `fetch-traces.ps1` 把过去 60min 自己 hosted agent 的运行抓成 `data/my-traces.json`
- 在本地 HTML 里看 Overview / Failures / Conversation 三个视图
- 理解 Foundry 自带的 thread → run → step 数据模型与 OTel span 的对应关系
- 在 personas / tools 上挂自定义业务 attribute,让 trace 更可观

## 4.2 配合 Copilot

| 任务 | VS Code 走法 | Copilot CLI 走法 |
|------|------------|------|
| 解释 span tree | Inspector 截图 → Copilot Chat | `gh copilot explain "<span 文本>"` |
| 写新的 OTel attribute | Inline Chat:`add OTel span via tracer, name "crm.lookup"` | `gh copilot suggest "<filename + 描述>"` |
| 调 Foundry tracing API 排查 404 / 401 | `@workspace 参考 #file:docs/cheatsheet-foundry-api.md,我调 ... 返回 404` | `gh copilot explain "<错误响应>"` |
| 深入 trace / failure 分析 | 关键词命中后自动加载 `.agents/skills/microsoft-foundry/foundry-agent/trace/` 与 `observe/` | 拼上对应 `.md` 作为 context |

## 4.3 制造一些 trace

```powershell
cd workshop\Lab-2-vibe-coding

$prompts = @(
  "帮我研究'消费级 AI 笔记应用'品类,2025 重点对比 5 家",
  "对比国内三大新茶饮品牌 2024 增速",
  "拉一下 https://example.invalid/secret 的内容",          # 触发 tool_error
  "X 公司值不值得投资?买入还是卖出?",                       # 触发 guardrail_refusal
  "帮我汇总几篇付费墙文章里的核心数据"                       # 触发 guardrail_refusal
)
foreach ($p in $prompts) {
  ..\scripts\invoke-hosted.ps1 -AgentName "research-agent-$env:STUDENT_SUFFIX" -Prompt $p
  Start-Sleep -Seconds 2
}
```

> Foundry tracing 一般 30s 内可查;不需要等 App Insights 摄入延迟。

## 4.4 拉 trace

```powershell
..\Lab-4-observability\fetch-traces.ps1 -Minutes 60
# ✅ 写出 ...\Lab-4-observability\data\my-traces.json
#    conversations=5  ok=2  fail=3  p95=11240ms
```

参数:

- `-Minutes 60`:时间窗口
- `-MaxThreads 20`:最多拉多少 thread
- `-AgentName research-agent-stu07`:默认从 `azd env STUDENT_SUFFIX` 推导
- `-ApiVersion 2025-05-15-preview`:若你环境的 preview 版本不同,可换

## 4.5 打开本地 HTML

```powershell
start ..\Lab-4-observability\index.html
# 顶栏数据源下拉 → 选 "my-traces.json (fetch-traces.ps1 拉的)"
```

三个 tab:

| Tab | 看什么 |
|------|------|
| Overview | QPS / p50 / p95 / failure rate / tokens 等 KPI |
| Failures | 按 `(error_type, operation, tool_name)` 聚类的失败表 |
| Conversation | 选一条 thread → span 时间线(invoke_agent / chat / execute_tool) |

点 Failures 表里的 `sample_conversation_id` → 跳到 Conversation 看完整 span 链。

## 4.6 关键概念(讲师 4 min)

### Foundry 数据模型 vs OTel span

```
Foundry                     │ 渲染成 spans-like
─────────────────────────── │ ───────────────────────────
thread                      │ conversation_id
run                         │ 一条 invoke_agent span(含 chat + execute_tool 子 span)
run_step (type=message)     │ chat span(含 tokens_in / tokens_out)
run_step.tool_calls[]       │ execute_tool span (tool_name = function.name)
```

`fetch-traces.ps1` 的核心就是这个映射。没有原生 OTel 级别的 latency 分位数,但 step 之间的 created_at / completed_at 差就是工具调用耗时。

API 细节见 [`cheatsheet-foundry-api.md`](cheatsheet-foundry-api.md);trace 高阶用法见 `.agents/skills/microsoft-foundry/foundry-agent/trace/`。

### 谁能看哪些 trace

学员 SP 在共享 project 上只有 `Azure AI User`,可以列**所有人**的 thread/run/step(共享 project 自身没有 thread 维度的 ACL)。`fetch-traces.ps1` 通过 `assistant_id == AGENT_NAME` 过滤,只渲染自己 agent 的 conversation。

> 如果想做更严格的隔离,要么开启 thread 级 ACL(preview 中),要么把每位学员部署到独立 project(资源更贵)。本工作坊接受这种"约定俗成只看自己"的简化。

## 4.7 自定义业务 span(加分)

`tools/web_search.py` 已经用 `tracer.start_as_current_span("web_search")`。你可以在 persona 触发的关键步骤里加业务属性:

```python
with tracer.start_as_current_span("crm.lookup") as span:
    span.set_attribute("customer.id", customer_id)
    span.set_attribute("customer.tier", tier)
```

部署后这些 attribute 会被 Foundry 收集;`fetch-traces.ps1` 当前没有解析自定义 attribute(聚焦于 step 结构),但加分挑战 §4.9 #2 给出了扩展思路。

> 更多 trace / observability 上手技巧:让 Copilot 读 `.agents/skills/microsoft-foundry/foundry-agent/observe/` 与 `trace/references/`。

## 4.8 出口检查点

✅ `fetch-traces.ps1` 写出 `data/my-traces.json`,且 `conversations` 数组非空
✅ 本地 HTML 选自己的 JSON 后,Overview 显示自己 agent 的 KPI
✅ Failures 页能点开一条失败 → 跳到 Conversation 看 span 时间线
✅ Conversation 页能指出 ≥3 类 span(`invoke_agent` / `execute_tool` / `chat`)

## 4.9 加分挑战

1. **接入 SSE / Streaming**:研究 `/responses` SSE 协议,让本地 HTML 实时刷新最新 run 而不用每次跑脚本。
2. **解析自定义 attribute**:扩展 `fetch-traces.ps1`,把 `step_details.tool_calls[].function.arguments` 里的关键参数(如 `customer.id`)作为 span attribute 挂上,在 Conversation 视图里高亮。
3. **加 `/tokens` 视图**:把 conversations 按时间桶聚合 token 用量,画堆叠柱状图。

## 4.10 故障速查

| 现象 | 处理 |
|------|------|
| `fetch-traces.ps1` 失败 / API 404 | preview API 路径漂移;试 `-ApiVersion v1` 或 `-ApiVersion 2024-12-01-preview` |
| `my-traces.json` 中 `conversations: []` | 等 30s 再跑;或确认讲师分配的 `STUDENT_SUFFIX` 与你部署的 agent 名一致 |
| HTML 顶栏看不到 `my-traces.json` | 在文件浏览器里确认 `data/my-traces.json` 存在;点"刷新" |
| 离线版(没有 echarts CDN 网络) | `index.html` 默认引 `cdn.jsdelivr.net`;离线场景把 echarts.min.js 下载到本地 |

→ [Wrap-up · 下一步](99-wrap-up.md)
