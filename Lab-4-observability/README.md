# Lab 4 · 本地 Observability (不走 portal、不依赖 App Insights)

> 一个单文件 HTML + 两个跨平台脚本（Windows PowerShell / macOS · Linux bash），凭 SP 直接调 Foundry agents 数据平面 API 拉自己 hosted agent 的运行数据。

## 文件

| 文件 | 用途 |
|------|------|
| `index.html` | 单文件 dashboard (echarts CDN)；视图：Overview / Failures / Conversation |
| `fetch-traces.ps1` | Windows 版：用 SP token 调 Foundry `/threads`、`/threads/{id}/runs`、`/threads/{id}/runs/{id}/steps`，规范化成 spans-like JSON |
| `fetch-traces.sh` | macOS · Linux 版：bash 端口，依赖 `curl` + `jq`，输出格式与 .ps1 一致 |
| `data/traces.sample.json` | 离线样本，HTML 默认加载这份 |
| `data/my-traces.json` | `fetch-traces.*` 写出的本人 trace (gitignore) |

## 用法

**Windows（PowerShell）**

```powershell
# 1. 制造点 trace：用 invoke-hosted.ps1 发几条
..\scripts\Windows\invoke-hosted.ps1 -AgentName "research-agent-$env:STUDENT_SUFFIX" -Prompt "帮我研究消费级 AI 笔记应用"
..\scripts\Windows\invoke-hosted.ps1 -AgentName "research-agent-$env:STUDENT_SUFFIX" -Prompt "对比国内三大新茶饮"

# 2. 拉 trace (默认过去 60 分钟，20 条 thread)
.\fetch-traces.ps1

# 3. 在浏览器打开 index.html，顶栏选 my-traces.json
start .\index.html
```

**macOS / Linux（bash）**

```bash
# 1. 制造点 trace：用 invoke-hosted.sh 发几条
../scripts/macOSLinux/invoke-hosted.sh --agent-name "research-agent-${STUDENT_SUFFIX}" --prompt "帮我研究消费级 AI 笔记应用"
../scripts/macOSLinux/invoke-hosted.sh --agent-name "research-agent-${STUDENT_SUFFIX}" --prompt "对比国内三大新茶饮"

# 2. 拉 trace（依赖 curl + jq：brew install jq 或 apt install -y jq）
./fetch-traces.sh

# 3. 在浏览器打开 index.html，顶栏选 my-traces.json
open ./index.html        # Linux 用 xdg-open ./index.html
```

> `fetch-traces.sh` 和 `fetch-traces.ps1` 输出格式完全一致（`data/my-metrics.js`），macOS / Linux 学员不再需要装 PowerShell。

完整教学步骤见 [HANDBOOK.md](HANDBOOK.md)。

## 数据 schema

```json
{
  "agent_name": "research-agent-stu07",
  "generated_at": "2026-05-14T10:30:00Z",
  "time_window_minutes": 60,
  "kpi": { "qps":..., "p50_ms":..., "p95_ms":..., "failure_rate":..., "total_tokens":..., "input_tokens":..., "output_tokens":... },
  "conversations": [
    {
      "conversation_id": "thread_xxx",
      "started_at": "...Z",
      "agent_name": "...",
      "success": true,
      "user_input": "...",
      "spans": [
        {"name":"...", "type":"request|invoke_agent|chat|execute_tool", "start":<ms>, "duration_ms":<ms>, "success":<bool>, "tool_name":"...", "tokens_in":..., "tokens_out":...}
      ]
    }
  ],
  "failure_clusters": [
    {"error_type":"tool_error|guardrail_refusal|run_failed", "operation":"...", "tool_name":"...", "count":N, "sample_conversation_id":"..."}
  ]
}
```

## API ·径与版本

Foundry agents 数据平面 API 在 preview 阶段，·径或参数名可能与你本地 azd extension 版本略有不一致。脚本默认 `2025-05-15-preview`，可用 `-ApiVersion 2024-12-01-preview` 等回退。

若调用失败，脚本会 fallback 到 `traces.sample.json`，并打印诊断；HTML 仍可演示。

## 学员权限

`fetch-traces.*` 用根目录 `.env` 里的 SP 凭据走 OAuth2 client_credentials 拿 token (audience `https://ai.azure.com/.default`)。对应 SP 已经在共享 project 上被讲师授予 `Cognitive Services User`。无需 portal、不需要 Log Analytics / App Insights 权限。
