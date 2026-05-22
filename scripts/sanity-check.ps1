<#
.SYNOPSIS
    Workshop sanity check — 验证学员的 .env + 凭据 + 共享 Foundry 资源是否就绪。

.DESCRIPTION
    在 Lab 0/1 后跑一次。**不依赖 az/azd CLI**, 直接用 .env 里的 Foundry api-key
    + ARM OAuth2 (SP) 跑只读 API:

        1. .env 关键变量都已填
        2. Foundry api-key 能调 /deployments  → 模型 deployment 存在
        3. Foundry api-key 能调 /agents       → 学员的 hosted agent 可达
        4. ARM token (SP) 能跑 ACR /listBuildSourceUploadUrl → AcrPush 权限就绪

.EXAMPLE
    .\scripts\sanity-check.ps1
#>
[CmdletBinding()]
param(
    [string]$ExpectedAgent,
    [string]$EnvFile
)

$ErrorActionPreference = "Continue"

# Pinned by the workshop.
$ApiVersion = '2025-11-15-preview'

function Write-Result {
    param([string]$Label, [bool]$Pass, [string]$Detail = "")
    if ($Pass) {
        Write-Host "✅ $Label" -ForegroundColor Green
        if ($Detail) { Write-Host "   $Detail" -ForegroundColor DarkGray }
    } else {
        Write-Host "❌ $Label" -ForegroundColor Red
        if ($Detail) { Write-Host "   $Detail" -ForegroundColor DarkYellow }
    }
}

Write-Host "`n=== Workshop Sanity Check ===`n" -ForegroundColor Cyan

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
function Resolve-Var {
    param([string]$Name)
    $procVal = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ($procVal) { return $procVal }
    if ($envFromFile.ContainsKey($Name)) { return $envFromFile[$Name] }
    return $null
}

$endpoint  = Resolve-Var 'AZURE_AI_PROJECT_ENDPOINT'
$model     = Resolve-Var 'AZURE_AI_MODEL_DEPLOYMENT_NAME'
$suffix    = Resolve-Var 'STUDENT_SUFFIX'
$acrName   = Resolve-Var 'AZURE_CONTAINER_REGISTRY_NAME'
$apiKey    = Resolve-Var 'FOUNDRY_API_KEY'
$clientId  = Resolve-Var 'AZURE_CLIENT_ID'
$secret    = Resolve-Var 'AZURE_CLIENT_SECRET'
$tenantId  = Resolve-Var 'AZURE_TENANT_ID'
$subId     = Resolve-Var 'AZURE_SUBSCRIPTION_ID'

Write-Result ".env: AZURE_AI_PROJECT_ENDPOINT"      ([bool]$endpoint) $endpoint
Write-Result ".env: AZURE_AI_MODEL_DEPLOYMENT_NAME" ([bool]$model)    $model
Write-Result ".env: STUDENT_SUFFIX"                 ([bool]$suffix)   $suffix
Write-Result ".env: AZURE_CONTAINER_REGISTRY_NAME"  ([bool]$acrName)  $acrName
Write-Result ".env: FOUNDRY_API_KEY"                ([bool]$apiKey)
Write-Result ".env: AZURE_TENANT_ID"                ([bool]$tenantId)
Write-Result ".env: AZURE_CLIENT_ID"                ([bool]$clientId)
Write-Result ".env: AZURE_CLIENT_SECRET"            ([bool]$secret)
Write-Result ".env: AZURE_SUBSCRIPTION_ID"          ([bool]$subId)

if (-not $ExpectedAgent) {
    if ($suffix) { $ExpectedAgent = "research-agent-$suffix" } else { $ExpectedAgent = "research-agent" }
}

# ---------------------------------------------------------------------------
# Foundry data plane via api-key
# ---------------------------------------------------------------------------
if ($endpoint -and $model -and $apiKey) {
    try {
        $r = Invoke-RestMethod -Method GET `
            -Uri "$endpoint/deployments?api-version=2025-05-15-preview" `
            -Headers @{ "api-key" = $apiKey } -TimeoutSec 15
        $items = if ($r.value) { @($r.value) } elseif ($r.data) { @($r.data) } else { @() }
        $found = @($items | Where-Object { $_.name -eq $model -or $_.id -eq $model }).Count -gt 0
        Write-Result "模型 deployment '$model' 在共享 project 中" $found "items=$($items.Count)"
    } catch {
        Write-Result "模型 deployment '$model' 在共享 project 中" $false $_.Exception.Message
    }
} else {
    Write-Result "模型 deployment 在共享 project 中" $false "缺前置 (endpoint/model/api-key)"
}

if ($endpoint -and $apiKey) {
    $url = "$endpoint/agents/$ExpectedAgent/endpoint/protocols/openai/responses?api-version=$ApiVersion"
    $body = @{ input = "ping"; store = $false } | ConvertTo-Json
    try {
        $r = Invoke-RestMethod -Method POST -Uri $url `
            -Headers @{ "api-key" = $apiKey } `
            -ContentType "application/json" -Body $body -TimeoutSec 60
        $ok = $r.status -eq 'completed'
        Write-Result "Hosted agent '$ExpectedAgent' 可达 + 跑通" $ok "status=$($r.status)"
    } catch {
        Write-Result "Hosted agent '$ExpectedAgent' 可达" $false $_.Exception.Message
    }
} else {
    Write-Result "Hosted agent '$ExpectedAgent' 可达" $false "缺前置 (endpoint/api-key)"
}

# ---------------------------------------------------------------------------
# ARM (SP) for ACR push capability
# ---------------------------------------------------------------------------
if ($acrName -and $clientId -and $secret -and $tenantId -and $subId) {
    try {
        $armToken = (Invoke-RestMethod -Method POST `
            -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body @{
                client_id     = $clientId
                client_secret = $secret
                scope         = 'https://management.azure.com/.default'
                grant_type    = 'client_credentials'
            } -TimeoutSec 30).access_token
        $acrUrl = "https://management.azure.com/subscriptions/$subId/resourceGroups/foundry-workshop/providers/Microsoft.ContainerRegistry/registries/$acrName/listBuildSourceUploadUrl?api-version=2019-06-01-preview"
        $r = Invoke-RestMethod -Method POST -Uri $acrUrl -Headers @{ Authorization = "Bearer $armToken" } -TimeoutSec 15
        Write-Result "ACR '$acrName' 可远程构建 (AcrPush + Contributor)" ([bool]$r.uploadUrl)
    } catch {
        Write-Result "ACR '$acrName' 可远程构建 (AcrPush + Contributor)" $false $_.Exception.Message
    }
} else {
    Write-Result "ACR '$acrName' 可远程构建" $false "缺 ACR name 或 SP 凭据"
}

Write-Host "`n如有 ❌, 把整段输出贴到助教频道。`n" -ForegroundColor Cyan
