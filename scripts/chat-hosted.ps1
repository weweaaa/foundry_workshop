<#
.SYNOPSIS
    打开本地图形化 chat UI, 跟 Lab 1/3 部署的 hosted agent 聊天 (api-key 模式)。

.DESCRIPTION
    最稳健路径 — 用 Foundry account-level API key 直接调 hosted agent:

        - 不依赖 az / azd CLI
        - 不依赖 AAD / SP / OAuth2
        - key 不过期, URL 可反复用
        - 学员 .env 里填 FOUNDRY_API_KEY 即可

    流程:
        1. 从 .env / 进程 env / azd env 读 FOUNDRY_API_KEY + endpoint + agent name
        2. 把这三项编码进 URL #cfg= (base64-json)
        3. 在默认浏览器中打开 scripts/chat-hosted/index.html

    凭据来源优先级 (越靠前优先级越高):
        1. 命令行参数 -ApiKey / -Endpoint / -AgentName
        2. 进程环境变量 FOUNDRY_API_KEY / AZURE_AI_PROJECT_ENDPOINT / AGENT_NAME
        3. workshop 根 .env (KEY=VALUE 行)
        4. azd env (azd env get-value <KEY>) — 仅当 azd 已装并在 azd env 目录里跑

.PARAMETER AgentName
    Hosted agent 名 (e.g. research-agent-stu07)。默认从 env 推导, 否则 `research-agent-<STUDENT_SUFFIX>`。

.PARAMETER ApiKey
    Foundry account API key (header: api-key)。默认 $env:FOUNDRY_API_KEY。

.PARAMETER Endpoint
    Foundry project endpoint。默认 $env:AZURE_AI_PROJECT_ENDPOINT。

.PARAMETER EnvFile
    从哪读 .env, 默认 workshop 根 .env (相对脚本所在目录)。

.PARAMETER NoOpen
    不自动打开浏览器, 只打印 URL。

.EXAMPLE
    # 推荐: 在 Lab-2-vibe-coding 目录, .env 已填好 FOUNDRY_API_KEY + endpoint
    cd Lab-2-vibe-coding
    ..\scripts\chat-hosted.ps1

.EXAMPLE
    # 显式传参 (绕开 .env / azd env)
    ..\scripts\chat-hosted.ps1 `
      -ApiKey    '84RaDhfu...' `
      -Endpoint  'https://itd-foundry.services.ai.azure.com/api/projects/itd-foundry-workshop' `
      -AgentName research-agent-stu07
#>
[CmdletBinding()]
param(
    [string]$AgentName,
    [string]$ApiKey,
    [string]$Endpoint,
    [string]$EnvFile,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'

# Pinned by the workshop — students don't tweak this.
$ApiVersion = '2025-11-15-preview'

function Write-Info  { param([string]$m) Write-Host "ℹ️  $m" -ForegroundColor Cyan }
function Write-Warn2 { param([string]$m) Write-Host "⚠️  $m" -ForegroundColor Yellow }
function Write-Ok    { param([string]$m) Write-Host "✅ $m" -ForegroundColor Green }
function Write-Err   { param([string]$m) Write-Host "❌ $m" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 1. Load .env (default: workshop root, one level above this script's folder)
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
    Write-Info "从 $EnvFile 读到 $($envFromFile.Count) 个变量"
}

function Resolve-Var {
    param([string]$ParamValue, [string]$Name)
    if ($ParamValue) { return $ParamValue }
    $procVal = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ($procVal) { return $procVal }
    if ($envFromFile.ContainsKey($Name)) { return $envFromFile[$Name] }
    try {
        $azdVal = (& azd env get-value $Name 2>$null | Out-String).Trim()
        if ($azdVal -and -not $azdVal.StartsWith('ERROR')) { return $azdVal }
    } catch {}
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
    Write-Err "缺以下变量: $($missing -join ', ')"
    Write-Host "   填到 workshop 根 .env 里, 或显式传 -ApiKey / -Endpoint 参数。" -ForegroundColor DarkGray
    Write-Host "   .env 例:" -ForegroundColor DarkGray
    Write-Host "     AZURE_AI_PROJECT_ENDPOINT=https://<account>.services.ai.azure.com/api/projects/<project>" -ForegroundColor DarkGray
    Write-Host "     FOUNDRY_API_KEY=<讲师下发的 Foundry account key>" -ForegroundColor DarkGray
    exit 1
}

Write-Info "endpoint = $Endpoint"
Write-Info "agent    = $AgentName"
Write-Info "auth     = api-key (Foundry account key, $($ApiKey.Length) chars)"

# ---------------------------------------------------------------------------
# 2. Serialize cfg into URL #cfg=
# ---------------------------------------------------------------------------
$cfg = [ordered]@{
    endpoint = $Endpoint
    agent    = $AgentName
    apiKey   = $ApiKey
    store    = $false
}
$json = $cfg | ConvertTo-Json -Compress
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
$b64 = [Convert]::ToBase64String($bytes)
$cfgFragment = [Uri]::EscapeDataString($b64)

$htmlPath = Join-Path $PSScriptRoot 'chat-hosted\index.html'
if (-not (Test-Path $htmlPath)) {
    Write-Err "找不到 $htmlPath。仓库被改坏了?"
    exit 1
}
$absPath = (Resolve-Path $htmlPath).Path
$fileUri = 'file:///' + ($absPath -replace '\\', '/') + '#cfg=' + $cfgFragment

Write-Host ""
Write-Ok "Chat UI URL (含 api-key, 不要分享):"
Write-Host "    $fileUri" -ForegroundColor DarkGray
Write-Host ""

# ---------------------------------------------------------------------------
# 3. Open browser
# ---------------------------------------------------------------------------
if ($NoOpen) {
    Write-Info "(-NoOpen) 复制上面 URL 到浏览器里打开即可。"
    exit 0
}

try {
    Start-Process $fileUri
    Write-Ok "已在默认浏览器中打开。api-key 不过期, URL 反复用即可。"
} catch {
    Write-Warn2 "Start-Process 失败 ($($_.Exception.Message)), 请手动粘上面 URL 到浏览器。"
}
