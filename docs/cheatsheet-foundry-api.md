# 速查卡 · Foundry agents 数据平面 API

> Lab 4 学员通过这些 REST 端点拉自己 hosted agent 的运行数据。所有调用都带 `Authorization: Bearer <token>`，token 来自 `az account get-access-token --resource https://ai.azure.com`。

## 基础变量

```powershell
$endpoint   = azd env get-value AZURE_AI_PROJECT_ENDPOINT
$agentName  = "research-agent-$env:STUDENT_SUFFIX"
$apiVersion = "2025-05-15-preview"
$token      = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv
$headers    = @{ Authorization = "Bearer $token" }
```

## 列最近的 thread

```powershell
Invoke-RestMethod -Method GET `
  -Uri "$endpoint/threads?api-version=$apiVersion&limit=20&order=desc" `
  -Headers $headers
```

返回：
```json
{
  "data": [
    {"id": "thread_abc", "created_at": 1716543210, "metadata": {...}},
    ...
  ]
}
```

## 列 thread 的 runs

```powershell
$tid = "thread_abc"
Invoke-RestMethod -Method GET `
  -Uri "$endpoint/threads/$tid/runs?api-version=$apiVersion&limit=20&order=desc" `
  -Headers $headers
```

run 字段：`id`、`assistant_id`（或 `agent_id`）、`status`（queued/in_progress/completed/failed）、`model`、`started_at`、`completed_at`、`usage.{prompt_tokens, completion_tokens}`。

## 列 run 的 steps

```powershell
$rid = "run_def"
Invoke-RestMethod -Method GET `
  -Uri "$endpoint/threads/$tid/runs/$rid/steps?api-version=$apiVersion&limit=50&order=asc" `
  -Headers $headers
```

step `type` 取值：
- `message_creation` —— 模型回话（chat span）
- `tool_calls` —— 工具调用（execute_tool span），细节在 `step_details.tool_calls[]`

每个 tool_call：
```json
{
  "id": "call_xyz",
  "type": "function",
  "function": {
    "name": "web_search",
    "arguments": "{\"query\":\"...\",\"count\":5}",
    "output": "{...}"
  }
}
```

## 调 hosted agent 的 responses 端点

```powershell
$url = "$endpoint/agents/$agentName/endpoint/protocols/openai/responses?api-version=2025-11-15-preview"
Invoke-RestMethod -Method POST -Uri $url -Headers $headers `
  -ContentType "application/json" `
  -Body (@{ input = "your prompt" } | ConvertTo-Json)
```

`api-version` 注意是 **`2025-11-15-preview`**，与 data plane 的 `2025-05-15-preview` 不同。`invoke-hosted.ps1` 已封装。

## API 版本漂移

Foundry agents 数据平面在 preview 阶段，版本号可能漂。常见可用值：

- `2025-05-15-preview`
- `2024-12-01-preview`
- `v1`

`fetch-traces.ps1 -ApiVersion <ver>` 切换。

## 故障速查

| 状态码 | 含义 |
|--------|------|
| 401 | token 过期 / SP 没 Azure AI User on project；重 `az login` 拿 token |
| 403 | project 范围 RBAC 不对；联系讲师 |
| 404 | 路径漂移；试不同 ApiVersion |
| 429 | preview 限流；指数退避重试 |
| 5xx | Foundry 临时；等 30s 重试 |

## 看不出 trace 是哪个学员的？

`run.assistant_id` 是带后缀的 agent 名（如 `research-agent-stu07`）。`fetch-traces.ps1` 用它过滤。无 thread/run 级 ACL —— 共享 project 的所有 agent 都能被列出，但默认按 agent 名过滤。
## 配合 Copilot 探索 API

更深入的 hosted agent / 模型部署 / observability 操作,直接调用 `microsoft-foundry` skill(`.agents/skills/microsoft-foundry/`)。它的子目录覆盖:

- `foundry-agent/invoke/` — invocations / responses 协议细节
- `foundry-agent/trace/` — trace 搜索、KQL 模板、failure 分析
- `foundry-agent/observe/` — 持续 eval、监控、CI/CD
- `models/deploy-model/` — 模型 deployment / capacity / 区域选择
- `rbac/`、`quota/`、`project/`、`resource/` — 资源与配额操作