<#
.SYNOPSIS
    拉 Foundry "Agents → Monitor → Operational metrics" 数据, 写成本地 JSON 给 dashboard 用。

.DESCRIPTION
    用 Azure Monitor REST API 拉项目级 metric 时间序列, 按 AgentId 拆分.
    走 SP ARM token (无 az login 依赖). Foundry api-key 在这条路径上没有 Monitor 权限,
    所以监控数据用 SP, 调用数据 (chat/invoke) 仍走 api-key.

    输出 JSON 给 ./index.html (echarts) 渲染.

.EXAMPLE
    .\fetch-traces.ps1 -Minutes 60 -Interval PT5M

.EXAMPLE
    .\fetch-traces.ps1 -AgentName research-agent-stu05 -Minutes 180
#>
[CmdletBinding()]
param(
    [string]$AgentName,
    [int]$Minutes = 60,
    [string]$Interval = 'PT5M',
    [string]$OutputPath = (Join-Path $PSScriptRoot 'data\my-metrics.js'),
    [string]$EnvFile
)

$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$m) Write-Host "ℹ️  $m" -ForegroundColor Cyan }
function Write-Warn2 { param([string]$m) Write-Host "⚠️  $m" -ForegroundColor Yellow }
function Write-Err   { param([string]$m) Write-Host "❌ $m" -ForegroundColor Red }
function Write-Ok    { param([string]$m) Write-Host "✅ $m" -ForegroundColor Green }

# ---------------------------------------------------------------------------
# 1. Load .env, resolve config
# ---------------------------------------------------------------------------
if (-not $EnvFile) { $EnvFile = Join-Path $PSScriptRoot '..\.env' }
$envFromFile = @{}
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $eq = $line.IndexOf('=')
            if ($eq -gt 0) {
                $k = $line.Substring(0, $eq).Trim()
                $v = $line.Substring($eq + 1).Trim().Trim('"').Trim("'")
                if ($v) { $envFromFile[$k] = $v }
            }
        }
    }
}
function Resolve-Var { param([string]$Name)
    $p = [Environment]::GetEnvironmentVariable($Name, 'Process'); if ($p) { return $p }
    if ($envFromFile.ContainsKey($Name)) { return $envFromFile[$Name] }
    return $null
}

$projectId = Resolve-Var 'AZURE_AI_PROJECT_ID'
$clientId  = Resolve-Var 'AZURE_CLIENT_ID'
$secret    = Resolve-Var 'AZURE_CLIENT_SECRET'
$tenantId  = Resolve-Var 'AZURE_TENANT_ID'
if (-not $projectId) { Write-Err "AZURE_AI_PROJECT_ID 未设置 (.env)."; exit 1 }
if (-not ($clientId -and $secret -and $tenantId)) {
    Write-Err "SP 凭据 (AZURE_CLIENT_ID/SECRET/TENANT_ID) 未在 .env 设置."; exit 1
}

if (-not $AgentName) {
    $AgentName = Resolve-Var 'AGENT_NAME'
    if (-not $AgentName) {
        $suffix = Resolve-Var 'STUDENT_SUFFIX'
        if ($suffix) { $AgentName = "research-agent-$suffix" } else { $AgentName = 'research-agent' }
    }
}
Write-Info "agent=$AgentName  window=${Minutes}min  interval=$Interval"

# ---------------------------------------------------------------------------
# 2. ARM SP token
# ---------------------------------------------------------------------------
try {
    $armToken = (Invoke-RestMethod -Method POST `
        -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{ client_id=$clientId; client_secret=$secret; scope='https://management.azure.com/.default'; grant_type='client_credentials' } `
        -TimeoutSec 30).access_token
} catch {
    Write-Err "OAuth2 token 失败: $($_.Exception.Message)"; exit 2
}

# ---------------------------------------------------------------------------
# 3. Query Azure Monitor metrics
# ---------------------------------------------------------------------------
$end   = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$start = [DateTime]::UtcNow.AddMinutes(-$Minutes).ToString("yyyy-MM-ddTHH:mm:ssZ")
$timespan = "$start/$end"

function Get-Metric {
    param([string[]]$Names, [string]$Aggregation, [string]$Filter = $null)
    $u = "https://management.azure.com$projectId/providers/microsoft.insights/metrics?api-version=2018-01-01&metricnames=$([Uri]::EscapeDataString($Names -join ','))&timespan=$timespan&interval=$Interval&aggregation=$Aggregation"
    if ($Filter) { $u += "&`$filter=$([Uri]::EscapeDataString($Filter))" }
    try {
        return (Invoke-RestMethod -Uri $u -Headers @{Authorization="Bearer $armToken"} -TimeoutSec 30).value
    } catch {
        $msg = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
        Write-Warn2 "metric query failed ($($Names -join ',')): $msg"
        return @()
    }
}

# 3a. AgentResponses split by AgentId (cross-student comparison)
$respByAgent = Get-Metric -Names @('AgentResponses') -Aggregation 'Total' -Filter "AgentId eq '*'"

# 3b. AgentInputTokens / AgentOutputTokens (project-wide, not split per agent in current preview)
$tokens = Get-Metric -Names @('AgentInputTokens','AgentOutputTokens','AgentToolCalls','AgentEvents','AgentMessages') -Aggregation 'Total'

# 3c. Model-level metrics live on the ACCOUNT scope, not project. Derive account ID.
$accountId = $projectId -replace '/projects/[^/]+$', ''
function Get-AccountMetric {
    param([string[]]$Names, [string]$Aggregation, [string]$Filter = $null)
    $u = "https://management.azure.com$accountId/providers/microsoft.insights/metrics?api-version=2018-01-01&metricnames=$([Uri]::EscapeDataString($Names -join ','))&timespan=$timespan&interval=$Interval&aggregation=$Aggregation"
    if ($Filter) { $u += "&`$filter=$([Uri]::EscapeDataString($Filter))" }
    try {
        return (Invoke-RestMethod -Uri $u -Headers @{Authorization="Bearer $armToken"} -TimeoutSec 30).value
    } catch {
        Write-Warn2 "account metric query failed ($($Names -join ',')): $($_.Exception.Message)"
        return @()
    }
}
$modelMetricsTotal = Get-AccountMetric -Names @('ModelRequests') -Aggregation 'Total' -Filter "ModelDeploymentName eq '*'"
$modelMetricsAvg   = Get-AccountMetric -Names @('TimeToResponse','TokensPerSecond') -Aggregation 'Average' -Filter "ModelDeploymentName eq '*'"

# ---------------------------------------------------------------------------
# 4. Reshape: find this student's AgentId timeseries (matches version suffix)
# ---------------------------------------------------------------------------
function Find-MyTimeseries {
    param($metricObj, [string]$agentName)
    if (-not $metricObj) { return $null }
    $allTs = @($metricObj.timeseries)
    # AgentId looks like "research-agent-stu05:1"
    foreach ($ts in $allTs) {
        $aid = ($ts.metadatavalues | Where-Object { $_.name.value -eq 'agentid' }).value
        if ($aid -like "$agentName`:*" -or $aid -eq $agentName) { return $ts }
    }
    return $null
}

function Sum-Timeseries { param($ts)
    $tot = 0
    if (-not $ts) { return 0 }
    foreach ($d in $ts.data) { if ($d.total) { $tot += [double]$d.total } }
    return $tot
}

# Build per-agent share + timeseries arrays
$agentResponsesMetric = $respByAgent | Where-Object { $_.name.value -eq 'AgentResponses' } | Select-Object -First 1
$agentsShare = @()
$myTimeseries = $null
if ($agentResponsesMetric) {
    foreach ($ts in $agentResponsesMetric.timeseries) {
        $aid = ($ts.metadatavalues | Where-Object { $_.name.value -eq 'agentid' }).value
        $tot = Sum-Timeseries $ts
        $agentsShare += [pscustomobject]@{ agentId = $aid; total = $tot }
        if ($aid -like "$AgentName`:*" -or $aid -eq $AgentName) { $myTimeseries = $ts }
    }
}
$agentsShare = @($agentsShare | Sort-Object total -Descending)

# Extract timestamps + values for charts
function Project-Series { param($ts, [string]$Field = 'total')
    $stamps = @(); $vals = @()
    if ($ts) {
        foreach ($d in $ts.data) {
            $stamps += $d.timeStamp
            $vals   += if ($d.$Field) { [double]$d.$Field } else { 0 }
        }
    }
    return [pscustomobject]@{ timestamps = $stamps; values = $vals }
}

$myResponsesSeries = Project-Series $myTimeseries 'total'

function First-Metric { param($list, [string]$Name)
    return ($list | Where-Object { $_.name.value -eq $Name } | Select-Object -First 1)
}

$projectInputTokens  = Project-Series (First-Metric $tokens 'AgentInputTokens').timeseries[0] 'total'
$projectOutputTokens = Project-Series (First-Metric $tokens 'AgentOutputTokens').timeseries[0] 'total'
$projectToolCalls    = Project-Series (First-Metric $tokens 'AgentToolCalls').timeseries[0] 'total'

$modelRequestsTs = (First-Metric $modelMetricsTotal 'ModelRequests').timeseries
$modelLatencyTs  = (First-Metric $modelMetricsAvg   'TimeToResponse').timeseries
$tpsSeriesTs     = (First-Metric $modelMetricsAvg   'TokensPerSecond').timeseries

# Pick first model deployment series (usually the one configured in .env)
$modelRequests   = Project-Series ($modelRequestsTs | Select-Object -First 1) 'total'
$modelLatencyAvg = Project-Series ($modelLatencyTs  | Select-Object -First 1) 'average'
$tpsAvg          = Project-Series ($tpsSeriesTs     | Select-Object -First 1) 'average'

# KPI: this student
$myTotalResponses = Sum-Timeseries $myTimeseries
# KPI: project totals
$projectInputTotal  = ($projectInputTokens.values  | Measure-Object -Sum).Sum
$projectOutputTotal = ($projectOutputTokens.values | Measure-Object -Sum).Sum
$projectToolTotal   = ($projectToolCalls.values    | Measure-Object -Sum).Sum

$result = [pscustomobject]@{
    agent_name          = $AgentName
    generated_at        = (Get-Date).ToUniversalTime().ToString('o')
    time_window_minutes = $Minutes
    interval            = $Interval

    kpi = [pscustomobject]@{
        my_total_responses     = [int]$myTotalResponses
        project_input_tokens   = [int]$projectInputTotal
        project_output_tokens  = [int]$projectOutputTotal
        project_total_tokens   = [int]($projectInputTotal + $projectOutputTotal)
        project_tool_calls     = [int]$projectToolTotal
        my_share_pct           = if ($agentsShare.Count -gt 0 -and ($agentsShare | Measure-Object -Property total -Sum).Sum -gt 0) {
                                     [math]::Round($myTotalResponses / ($agentsShare | Measure-Object -Property total -Sum).Sum * 100, 1)
                                 } else { 0 }
    }

    series = [pscustomobject]@{
        my_responses        = $myResponsesSeries
        project_in_tokens   = $projectInputTokens
        project_out_tokens  = $projectOutputTokens
        project_tool_calls  = $projectToolCalls
        model_requests      = $modelRequests
        model_latency_ms    = $modelLatencyAvg
        tokens_per_second   = $tpsAvg
    }

    agents_share = $agentsShare
}

$json = $result | ConvertTo-Json -Depth 12
$outDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
# Write as JS module to avoid file:// CORS on fetch() of JSON.
$jsContent = "window.__METRICS__ = " + $json + ";`n"
[System.IO.File]::WriteAllText($OutputPath, $jsContent, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Ok "写出 $OutputPath"
Write-Host ("   my_responses={0}  my_share={1}%  project_in_tokens={2}  project_out_tokens={3}" -f `
    $result.kpi.my_total_responses, $result.kpi.my_share_pct, $result.kpi.project_input_tokens, $result.kpi.project_output_tokens) `
    -ForegroundColor DarkGray
Write-Host ""
Write-Host "用浏览器打开 .\index.html 即可查看。" -ForegroundColor Yellow
