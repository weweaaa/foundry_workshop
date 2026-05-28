# Lab 4 · 本地 Observability：Foundry operational metrics（10 min）

Lab 4 用本地 HTML 看 hosted agent 的 operational metrics：我的 AgentResponses、项目 tokens、tool calls、各 agent share、model latency。数据来自 Azure Monitor REST API，不走 Portal / App Insights，也不需要 `az login`。

> 不使用 Azure Portal，不依赖 Application Insights，不要求 `az login`。

## 4.1 目标

- 制造几次 hosted agent 调用，让 Monitor 有数据。
- 用 `fetch-traces.ps1` / `fetch-traces.sh` 写出 `data/my-metrics.js`。
- 打开本地 `index.html` 查看 metrics dashboard。
- 理解哪些指标是按 agent 拆分，哪些是项目级共享指标。

## 4.2 Agent-driven 观测方式

这个目录不需要 Copilot 帮你创建 Azure 资源。它主要做三件事：生成测试 prompt、解释 `fetch-traces.*` 输出、帮助扩展 `index.html` 的图表。

```text
@workspace 我正在做 Lab 4。请阅读 #file:Lab-4-observability/README.md、#file:Lab-4-observability/fetch-traces.ps1、#file:Lab-4-observability/fetch-traces.sh 和 #file:Lab-4-observability/index.html。
请告诉我如何生成最小测试流量、拉取 metrics、判断 dashboard 是否完成。
```

| 人类负责 | Copilot coding agent 负责 | 完成信号 |
|----------|---------------------------|----------|
| 判断测试问题是否符合业务和安全边界 | 生成测试 prompt 集、解释脚本输出、定位 metrics 为空的原因 | `data/my-metrics.js` 写出，`我的 AgentResponses` 大于 0，能解释指标粒度 |

## 4.3 配合 Copilot

| 任务 | VS Code 走法（主路径） | Copilot TUI 走法（可选） |
|------|--------------|------------------|
| 解释 dashboard 指标 | `@workspace 解释 #file:Lab-4-observability/index.html 的 KPI` | 运行 `copilot` 进入 chat，粘贴指标名或截图文字 |
| 排查 metrics 为空 | 粘贴 `fetch-traces.*` 输出 | 粘贴错误响应和本 Lab 约束，让 TUI chat 做最小排查 |
| 生成测试问题集 | `@workspace 根据 persona 生成 5 条 hosted 调用 prompt` | 粘贴 persona / skill 摘要，让 TUI chat 生成测试 prompt 集 |
| 扩展图表 | `#file:index.html add a chart for project_tool_calls` | 粘贴修改目标；涉及多文件改动时仍推荐回到 VS Code 主路径 |
| 深入 Foundry observability | 询问 `microsoft-foundry observe / trace` | 拼上 `.agents/skills/microsoft-foundry/foundry-agent/observe/` 相关文档 |

## 4.4 文件

| 文件 | 用途 |
|------|------|
| `index.html` | 本地 dashboard；显示我的 AgentResponses、项目 tokens、各 agent share、model latency |
| `fetch-traces.ps1` | Windows 版 metrics 拉取脚本，输出 `data/my-metrics.js` |
| `fetch-traces.sh` | macOS / Linux 版，依赖 `curl` + `jq`，输出格式与 PowerShell 版一致 |
| `data/my-metrics.js` | 脚本生成的数据文件（gitignore） |
| `data/responses.jsonl` | `invoke-hosted.*` 追加的 response 索引（gitignore，供后续扩展用） |

## 4.5 制造 metrics

先让 Copilot 根据 persona 生成覆盖面，而不是手写随机问题：

```text
@workspace 根据 #file:Lab-2-vibe-coding/personas/research-agent.md 和 #file:Lab-2-vibe-coding/skills/market-research/SKILL.md，生成 5 条 Lab 4 hosted 调用 prompt：3 条成功调研、1 条 guardrail 拒答、1 条可能触发工具失败。输出 PowerShell 和 bash 数组，不要包含敏感信息。
```

下面是默认最小集合；你也可以替换成 Copilot 生成的业务集合。从 `Lab-2-vibe-coding` 目录执行。

**Windows（PowerShell）**

```powershell
$prompts = @(
  "帮我研究'消费级 AI 笔记应用'品类，2025 重点对比 5 家",
  "对比国内三大新茶饮品牌 2024 增速",
  "X 公司值不值得投资？买入还是卖出？"
)
foreach ($p in $prompts) {
  ..\scripts\Windows\invoke-hosted.ps1 -Prompt $p
  Start-Sleep -Seconds 2
}
```

**macOS / Linux（bash）**

```bash
prompts=(
  "帮我研究《消费级 AI 笔记应用》品类，2025 重点对比 5 家"
  "对比国内三大新茶饮品牌 2024 增速"
  "X 公司值不值得投资？买入还是卖出？"
)
for p in "${prompts[@]}"; do
  ../scripts/macOSLinux/invoke-hosted.sh --prompt "$p"
  sleep 2
done
```

等待 1-2 分钟，让 Azure Monitor 完成摄入。

## 4.6 拉取 metrics

**Windows（PowerShell）**

```powershell
..\Lab-4-observability\fetch-traces.ps1 -Minutes 60 -Interval PT5M
# 写出 ...\Lab-4-observability\data\my-metrics.js
```

**macOS / Linux（bash）**

```bash
../Lab-4-observability/fetch-traces.sh --minutes 60 --interval PT5M
# 写出 .../Lab-4-observability/data/my-metrics.js
```

常用参数：

| PowerShell | bash | 含义 |
|------------|------|------|
| `-Minutes 60` | `--minutes 60` | 查询时间窗口 |
| `-Interval PT5M` | `--interval PT5M` | 聚合粒度 |
| `-AgentName research-agent-stu07` | `--agent-name research-agent-stu07` | 指定 agent；默认由 `STUDENT_SUFFIX` 推导 |
| `-OutputPath ...` | `--output-path ...` | 输出路径；默认 `data/my-metrics.js` |

如果输出为空，把脚本摘要交给 Copilot：

```text
这是 fetch-traces 的输出。请判断是没有调用流量、Azure Monitor 摄入延迟、AgentName 过滤不匹配，还是 SP 权限问题；只给最小排查命令。
```

## 4.7 打开本地 dashboard

**Windows（PowerShell）**

```powershell
start ..\Lab-4-observability\index.html
```

**macOS / Linux（bash）**

```bash
open ../Lab-4-observability/index.html      # Linux: xdg-open ../Lab-4-observability/index.html
```

页面包含：

| 区域 | 说明 |
|------|------|
| KPI cards | 我的 responses、项目 tokens、tool calls、占比 |
| 我的 AgentResponses | 按 `AgentId` 过滤到自己的 hosted agent |
| 项目 Input/Output Tokens | project-wide 指标，当前 preview 不按学员拆分 |
| AgentResponses share | 同一 project 内各 agent 的 responses 分布 |
| Model Requests / Latency | account 级模型指标 |

解读时可以问：

```text
这是 Lab 4 dashboard 的 KPI 和图表文字。请分别说明哪些指标代表我的 agent，哪些是共享 project/account 级指标；如果 my_responses 小于刚才调用次数，给出可能原因。
```

完成后让 Copilot 复盘：

```text
这是 data/my-metrics.js 中的 kpi 和 agents_share。请解释我的 agent 是否产生了流量、project-wide tokens 是否可按学员拆分、以及 dashboard 是否达到 Lab 4 完成信号。
```

## 4.8 数据 schema

`data/my-metrics.js` 是一个可被 `file://` 页面直接加载的脚本：

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

## 4.9 关键概念

```text
Hosted /responses 调用
  │
  ├─ invoke-hosted.* 使用 FOUNDRY_API_KEY 调 agent endpoint
  │
  ▼
Foundry / Azure Monitor 指标
  ├─ AgentResponses          可按 AgentId 拆分
  ├─ AgentInputTokens        project-wide
  ├─ AgentOutputTokens       project-wide
  ├─ AgentToolCalls          project-wide
  ├─ ModelRequests           account-wide
  └─ TimeToResponse          account-wide
```

这不是逐条 conversation trace，而是课堂里更稳定、权限更简单的 operational metrics 路径。`invoke-hosted.*` 仍会把 `response_id` 追加到 `data/responses.jsonl`，可作为加分挑战扩展到逐条 response 详情。

## 4.10 出口检查点

- `fetch-traces.*` 写出 `data/my-metrics.js`。
- `index.html` 不再显示空状态。
- KPI 中 `我的 AgentResponses` 大于 0。
- 能解释哪些指标是自己的，哪些是共享 project/account 级指标。
- Copilot 能根据 dashboard 给出一个“是否可进入 wrap-up”的判断。

## 4.11 故障速查

| 现象 | 处理 |
|------|------|
| `data/my-metrics.js` 不存在 | 先运行 `fetch-traces.*` |
| `my_responses=0` | 等 1-2 分钟后重跑；确认 `STUDENT_SUFFIX` 和 agent 名一致 |
| 401 / token 获取失败 | 检查 `.env` 中 `AZURE_CLIENT_ID/SECRET/TENANT_ID` |
| metrics query 403 | SP 缺 Azure Monitor 读权限或 project ID 不对；联系讲师 |
| HTML 没图表 | 确认有网络加载 ECharts CDN；离线时需把 `echarts.min.js` 下载到本地并改 `index.html` |

## 4.12 加分挑战

1. 让 Copilot 把 `responses.jsonl` 中的 response id 拉成逐条 conversation 详情视图。
2. 让 Copilot 在 `index.html` 增加 tool calls 时间序列图，并解释它改了哪些 DOM / chart option。
3. 让 Copilot 把 `data/my-metrics.js` 改成多个学员对比视图，用于讲师汇总。

→ [回到根 README 的 Wrap-up](../README.md#wrap-up--下一步)
