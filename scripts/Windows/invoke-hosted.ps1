<#
.SYNOPSIS
    命令行调用 hosted Foundry agent (Lab 1/3 验证, Lab 4 trace 来源)。

.DESCRIPTION
    用 Foundry api-key (header) 直接调 /responses, 不依赖 az / azd / AAD / SP / OAuth2.

    默认 store=true: response 写进 Foundry 内置存储 (供 Lab 4 dashboard 后续按 ID 拉详情)。
    每次调用把 {response_id, agent_name, started_at, prompt, store} 追加到
    `Lab-4-observability/data/responses.jsonl` (一行一条) 作为 Lab 4 的 trace 索引。

    凭据来源优先级: 显式参数 > 进程 env > workshop 根 .env

.PARAMETER NoStore
    关掉 store (默认 store=true)。关掉以后 Lab 4 dashboard 拿不到这次 trace 详情。

.EXAMPLE
    ..\scripts\Windows\invoke-hosted.ps1 -AgentName research-agent-stu05 -Prompt "ping"

.EXAMPLE
    ..\scripts\Windows\invoke-hosted.ps1 -AgentName research-agent-stu05 -StatusOnly
#>
[CmdletBinding()]
param(
    [string]$AgentName,
    [string]$Prompt = "Hello, who are you?",
    [switch]$StatusOnly,
    [switch]$NoStore,
    [string]$ApiKey,
    [string]$Endpoint,
    [string]$EnvFile
)

$ErrorActionPreference = 'Stop'
$ApiVersion = '2025-11-15-preview'

# Load .env
if (-not $EnvFile) { $EnvFile = Join-Path $PSScriptRoot '..\..\.env' }
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
function Resolve-Var {
    param([string]$ParamValue, [string]$Name)
    if ($ParamValue) { return $ParamValue }
    $procVal = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ($procVal) { return $procVal }
    if ($envFromFile.ContainsKey($Name)) { return $envFromFile[$Name] }
    return $null
}

$ApiKey   = Resolve-Var $ApiKey   'FOUNDRY_API_KEY'
$Endpoint = Resolve-Var $Endpoint 'AZURE_AI_PROJECT_ENDPOINT'
if (-not $AgentName) {
    $AgentName = Resolve-Var $null 'AGENT_NAME'
    if (-not $AgentName) {
        $suffix = Resolve-Var $null 'STUDENT_SUFFIX'
        if ($suffix) { $AgentName = "research-agent-$suffix" } else { $AgentName = 'research-agent' }
    }
}

$missing = @()
if (-not $ApiKey)   { $missing += 'FOUNDRY_API_KEY' }
if (-not $Endpoint) { $missing += 'AZURE_AI_PROJECT_ENDPOINT' }
if ($missing.Count -gt 0) {
    Write-Host "❌ 缺以下变量: $($missing -join ', ') — 请把 .env.example 复制成 .env 并填好。" -ForegroundColor Red
    exit 1
}

$responsesUrl = "$Endpoint/agents/$AgentName/endpoint/protocols/openai/responses?api-version=$ApiVersion"
$headers = @{ "api-key" = $ApiKey }

if ($StatusOnly) {
    $url = "$Endpoint/agents/$AgentName" + "?api-version=$ApiVersion"
    try {
        $r = Invoke-WebRequest -Uri $url -Method Get -Headers $headers -UseBasicParsing -TimeoutSec 15
        Write-Host "status=Reachable, http=$($r.StatusCode), agent=$AgentName" -ForegroundColor Green
        exit 0
    } catch {
        Write-Host "status=Unreachable, error=$($_.Exception.Message)" -ForegroundColor Red
        exit 2
    }
}

$store = -not $NoStore
$body = @{ input = $Prompt; store = $store } | ConvertTo-Json -Depth 8

Write-Host "→ POST $responsesUrl  (store=$store)" -ForegroundColor Cyan
Write-Host "→ prompt: $Prompt" -ForegroundColor DarkGray

try {
    # Send body as UTF-8 bytes so non-ASCII prompts survive PS5.1 → curl/native pipeline
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $resp = Invoke-RestMethod -Method POST -Uri $responsesUrl `
        -Headers $headers -ContentType "application/json; charset=utf-8" -Body $bodyBytes -TimeoutSec 120
    Write-Host "`n--- Response ---" -ForegroundColor Green
    $resp | ConvertTo-Json -Depth 10

    if ($store -and $resp.id) {
        $traceDir = Join-Path $PSScriptRoot '..\..\Lab-4-observability\data'
        if (-not (Test-Path $traceDir)) { New-Item -ItemType Directory -Path $traceDir -Force | Out-Null }
        $jsonl = Join-Path $traceDir 'responses.jsonl'
        $entry = [ordered]@{
            response_id = $resp.id
            agent_name  = $AgentName
            started_at  = (Get-Date).ToUniversalTime().ToString('o')
            prompt      = $Prompt
            store       = $true
        } | ConvertTo-Json -Compress
        # PS 5.1 Add-Content/Out-File default to ANSI; write UTF-8 bytes explicitly.
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($entry + "`n")
        $fs = [System.IO.File]::Open($jsonl, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
        try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Close() }
        Write-Host "→ trace index → $jsonl" -ForegroundColor DarkGray
    }
} catch {
    Write-Host "❌ Invocation failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message -ForegroundColor DarkYellow }
    exit 3
}
