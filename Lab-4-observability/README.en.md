# Lab 4 · Local Observability: Foundry Operational Metrics (10 min)

Lab 4 uses local HTML to inspect operational metrics for your hosted agent: your AgentResponses, project tokens, tool calls, agent share, and model latency. Data comes from the Azure Monitor REST API. It does not use Portal / App Insights, and it does not require `az login`.

> No Azure Portal, no Application Insights dependency, no `az login` requirement.

## 4.1 Goals

- Generate a few hosted-agent calls so Monitor has data.
- Use `fetch-traces.ps1` / `fetch-traces.sh` to write `data/my-metrics.js`.
- Open local `index.html` and view the metrics dashboard.
- Understand which metrics are split by agent and which are shared project/account-level metrics.

## 4.2 Agent-driven Observability Flow

This directory does not need Copilot to create Azure resources. Its main jobs are generating test prompts, explaining `fetch-traces.*` output, and helping extend `index.html` charts.

```text
@workspace I am working on Lab 4. Read #file:Lab-4-observability/README.md, #file:Lab-4-observability/fetch-traces.ps1, #file:Lab-4-observability/fetch-traces.sh, and #file:Lab-4-observability/index.html.
Tell me how to generate minimal test traffic, fetch metrics, and decide whether the dashboard is complete.
```

| Human owns | Copilot coding agent owns | Completion signal |
|------------|---------------------------|-------------------|
| Decide whether test prompts fit the business and safety boundaries | Generate test prompts, explain script output, identify why metrics are empty | `data/my-metrics.js` is written, `My AgentResponses` is greater than 0, and metric granularity is understood |

## 4.3 Working with Copilot

| Task | VS Code path (main) | Copilot TUI path (optional) |
|------|---------------------|-----------------------------|
| Explain dashboard metrics | `@workspace Explain KPI in #file:Lab-4-observability/index.html` | Run `copilot` and paste metric names or screenshot text |
| Troubleshoot empty metrics | Paste `fetch-traces.*` output | Paste the error response and this lab's constraints, then ask for minimal troubleshooting |
| Generate test prompts | `@workspace Generate 5 hosted-call prompts from the persona` | Paste persona / skill summary into TUI chat and ask for a test prompt set |
| Extend chart | `#file:index.html add a chart for project_tool_calls` | Paste the target change; for multi-file edits, prefer VS Code main path |
| Deep Foundry observability | Ask about `microsoft-foundry observe / trace` | Paste relevant `.agents/skills/microsoft-foundry/foundry-agent/observe/` documentation |

## 4.4 Files

| File | Purpose |
|------|---------|
| `index.html` | Local dashboard for My AgentResponses, project tokens, agent share, model latency |
| `fetch-traces.ps1` | Windows metrics fetch script; outputs `data/my-metrics.js` |
| `fetch-traces.sh` | macOS / Linux version; requires `curl` + `jq`; same output format as PowerShell |
| `data/my-metrics.js` | Generated data file (gitignored) |
| `data/responses.jsonl` | Response index appended by `invoke-hosted.*` (gitignored, useful for future extensions) |

## 4.5 Generate Metrics

First ask Copilot to generate coverage from the persona instead of writing random prompts manually:

```text
@workspace Based on #file:Lab-2-vibe-coding/personas/research-agent.md and #file:Lab-2-vibe-coding/skills/market-research/SKILL.md, generate 5 Lab 4 hosted-call prompts: 3 successful research prompts, 1 guardrail refusal, and 1 likely tool-failure case. Output PowerShell and bash arrays and include no sensitive information.
```

The following is the default minimal set. You can replace it with a Copilot-generated business set. Run from `Lab-2-vibe-coding`.

**Windows (PowerShell)**

```powershell
$prompts = @(
  "Research the consumer AI note-taking app category and compare five key players in 2025.",
  "Compare the 2024 growth of the three largest Chinese new-style tea brands.",
  "Is Company X worth investing in? Buy or sell?"
)
foreach ($p in $prompts) {
  ..\scripts\Windows\invoke-hosted.ps1 -Prompt $p
  Start-Sleep -Seconds 2
}
```

**macOS / Linux (bash)**

```bash
prompts=(
  "Research the consumer AI note-taking app category and compare five key players in 2025."
  "Compare the 2024 growth of the three largest Chinese new-style tea brands."
  "Is Company X worth investing in? Buy or sell?"
)
for p in "${prompts[@]}"; do
  ../scripts/macOSLinux/invoke-hosted.sh --prompt "$p"
  sleep 2
done
```

Wait 1-2 minutes for Azure Monitor ingestion.

## 4.6 Fetch Metrics

**Windows (PowerShell)**

```powershell
..\Lab-4-observability\fetch-traces.ps1 -Minutes 60 -Interval PT5M
# Writes ...\Lab-4-observability\data\my-metrics.js
```

**macOS / Linux (bash)**

```bash
../Lab-4-observability/fetch-traces.sh --minutes 60 --interval PT5M
# Writes .../Lab-4-observability/data/my-metrics.js
```

Common parameters:

| PowerShell | bash | Meaning |
|------------|------|---------|
| `-Minutes 60` | `--minutes 60` | Query window |
| `-Interval PT5M` | `--interval PT5M` | Aggregation granularity |
| `-AgentName research-agent-stu07` | `--agent-name research-agent-stu07` | Specify agent; default is inferred from `STUDENT_SUFFIX` |
| `-OutputPath ...` | `--output-path ...` | Output path; default is `data/my-metrics.js` |

If output is empty, give the script summary to Copilot:

```text
Here is the fetch-traces output. Decide whether the issue is no call traffic, Azure Monitor ingestion delay, AgentName filter mismatch, or SP permission. Give only minimal troubleshooting commands.
```

## 4.7 Open the Local Dashboard

**Windows (PowerShell)**

```powershell
start ..\Lab-4-observability\index.html
```

**macOS / Linux (bash)**

```bash
open ../Lab-4-observability/index.html      # Linux: xdg-open ../Lab-4-observability/index.html
```

Dashboard areas:

| Area | Meaning |
|------|---------|
| KPI cards | My responses, project tokens, tool calls, share |
| My AgentResponses | Filtered to your hosted agent by `AgentId` |
| Project Input/Output Tokens | Project-wide metrics; current preview does not split by student |
| AgentResponses share | Response distribution across agents in the same project |
| Model Requests / Latency | Account-level model metrics |

Ask Copilot to interpret:

```text
Here are the KPI and chart texts from the Lab 4 dashboard. Explain which metrics represent my agent and which are shared project/account-level metrics. If my_responses is lower than the number of calls I just made, give possible reasons.
```

Afterward, ask Copilot to recap:

```text
Here are kpi and agents_share from data/my-metrics.js. Explain whether my agent generated traffic, whether project-wide tokens can be split by student, and whether the dashboard meets the Lab 4 completion signal.
```

## 4.8 Data Schema

`data/my-metrics.js` is a script that can be loaded directly by a `file://` page:

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

## 4.9 Key Concepts

```text
Hosted /responses call
  │
  ├─ invoke-hosted.* calls the agent endpoint with FOUNDRY_API_KEY
  │
  ▼
Foundry / Azure Monitor metrics
  ├─ AgentResponses          split by AgentId
  ├─ AgentInputTokens        project-wide
  ├─ AgentOutputTokens       project-wide
  ├─ AgentToolCalls          project-wide
  ├─ ModelRequests           account-wide
  └─ TimeToResponse          account-wide
```

This is not per-conversation trace. It is a more stable classroom path with simpler permissions: operational metrics. `invoke-hosted.*` still appends `response_id` to `data/responses.jsonl`, which can be used for future response-detail extensions.

## 4.10 Exit Checkpoint

- `fetch-traces.*` writes `data/my-metrics.js`.
- `index.html` no longer shows an empty state.
- `My AgentResponses` is greater than 0.
- You can explain which metrics are yours and which are shared project/account-level metrics.
- Copilot can judge whether you are ready for wrap-up based on the dashboard.

## 4.11 Troubleshooting

| Symptom | Fix |
|---------|-----|
| `data/my-metrics.js` does not exist | Run `fetch-traces.*` first |
| `my_responses=0` | Wait 1-2 minutes and rerun; confirm `STUDENT_SUFFIX` and agent name match |
| 401 / token acquisition failure | Check `.env` `AZURE_CLIENT_ID/SECRET/TENANT_ID` |
| metrics query 403 | SP lacks Azure Monitor read permission or project ID is wrong; contact the instructor |
| HTML has no charts | Confirm ECharts CDN is reachable; offline use requires downloading `echarts.min.js` and updating `index.html` |

## 4.12 Bonus Challenges

1. Ask Copilot to turn response IDs from `responses.jsonl` into a per-response detail view.
2. Ask Copilot to add a tool calls time-series chart to `index.html` and explain the DOM / chart option changes.
3. Ask Copilot to turn `data/my-metrics.js` into a multi-student comparison view for instructor summaries.

→ [Back to root README Wrap-up](../README.en.md#wrap-up--next-steps)