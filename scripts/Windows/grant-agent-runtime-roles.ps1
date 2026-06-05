<#
.SYNOPSIS
    Workshop postdeploy hook: grant runtime roles to a Foundry hosted agent's per-version MIs.

.DESCRIPTION
    Every `azd deploy` of a hosted Foundry agent creates two per-version managed identities
    (instance_identity + blueprint). For the container to actually start and the agent code
    inside it to call the model deployment, these MIs need:

        AcrPull         on the workshop ACR             — to pull the image
        Azure AI User   on the Foundry account+project  — for DefaultAzureCredential to reach
                                                          chat/completions inside the container

    The student SP holds a RG-scoped `User Access Administrator` role *constrained* (RBAC
    condition v2) to ONLY allow assigning these two role IDs, so this script is safe to run
    on every deploy.

    Reads everything from `azd env get-value` + workshop `.env` (no `az login` required).
    Idempotent: existing role assignments are skipped.

.EXAMPLE
    # Run manually (from Lab-2-vibe-coding dir):
    pwsh ..\scripts\Windows\grant-agent-runtime-roles.ps1

    # Or wired via `hooks.postdeploy` in azure.yaml — fires automatically after every `azd deploy`.
#>
[CmdletBinding()]
param(
    [string]$AgentName,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$TenantId,
    [string]$SubscriptionId,
    [string]$Endpoint,
    [string]$ProjectId,
    [string]$AcrName,
    [string]$FoundryResourceGroup,
    [string]$AcrResourceGroup,
    [string]$EnvFile,
    [string]$ApiVersion = '2025-11-15-preview'
)

$ErrorActionPreference = 'Stop'

function Write-Info { param([string]$m) Write-Host "ℹ️  $m" -ForegroundColor Cyan }
function Write-Ok   { param([string]$m) Write-Host "✅ $m" -ForegroundColor Green }
function Write-Warn { param([string]$m) Write-Host "⚠️  $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "❌ $m" -ForegroundColor Red }

# Constants (built-in Azure RBAC role IDs)
$ACR_PULL_ROLE_ID       = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
$AZURE_AI_USER_ROLE_ID  = '53ca6127-db72-4b80-b1b0-d745d6d5456d'

# ---------------------------------------------------------------------------
# 1. Resolve config: param > process env > workshop .env > azd env
# ---------------------------------------------------------------------------
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
    try {
        $azdVal = (& azd env get-value $Name 2>$null | Out-String).Trim()
        if ($azdVal -and -not $azdVal.StartsWith('ERROR')) { return $azdVal }
    } catch {}
    return $null
}

$ClientId       = Resolve-Var $ClientId       'AZURE_CLIENT_ID'
$ClientSecret   = Resolve-Var $ClientSecret   'AZURE_CLIENT_SECRET'
$TenantId       = Resolve-Var $TenantId       'AZURE_TENANT_ID'
$SubscriptionId = Resolve-Var $SubscriptionId 'AZURE_SUBSCRIPTION_ID'
$Endpoint       = Resolve-Var $Endpoint       'AZURE_AI_PROJECT_ENDPOINT'
$ProjectId      = Resolve-Var $ProjectId      'AZURE_AI_PROJECT_ID'
$AcrName        = Resolve-Var $AcrName        'AZURE_CONTAINER_REGISTRY_NAME'
$FoundryResourceGroup = Resolve-Var $FoundryResourceGroup 'AZURE_RESOURCE_GROUP'
$AcrResourceGroup     = Resolve-Var $AcrResourceGroup     'AZURE_CONTAINER_REGISTRY_RESOURCE_GROUP'
if (-not $AgentName) {
    $AgentName = Resolve-Var $null 'AGENT_NAME'
    if (-not $AgentName) {
        $suffix = Resolve-Var $null 'STUDENT_SUFFIX'
        if ($suffix) { $AgentName = "research-agent-$suffix" } else { $AgentName = 'research-agent' }
    }
}

$missing = @()
foreach ($pair in @(@($ClientId,'AZURE_CLIENT_ID'),@($ClientSecret,'AZURE_CLIENT_SECRET'),@($TenantId,'AZURE_TENANT_ID'),@($SubscriptionId,'AZURE_SUBSCRIPTION_ID'),@($Endpoint,'AZURE_AI_PROJECT_ENDPOINT'),@($AcrName,'AZURE_CONTAINER_REGISTRY_NAME'))) {
    if (-not $pair[0]) { $missing += $pair[1] }
}
if ($missing.Count -gt 0) {
    Write-Err "缺以下变量: $($missing -join ', ')"
    exit 1
}

# Derive Foundry scope strings from project endpoint + ARM project ID.
# Endpoint format: https://<account>.services.ai.azure.com/api/projects/<project>
if ($Endpoint -notmatch '^https://([^.]+)\.services\.ai\.azure\.com/api/projects/([^/?#]+)') {
    Write-Err "AZURE_AI_PROJECT_ENDPOINT format unexpected: $Endpoint"
    exit 1
}
$accountName = $Matches[1]
$projectName = $Matches[2]

if ($ProjectId) {
    if ($ProjectId -match '^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\.CognitiveServices/accounts/([^/]+)/projects/([^/]+)$') {
        $projectSubscriptionId = $Matches[1]
        $FoundryResourceGroup = $Matches[2]
        $accountName = $Matches[3]
        $projectName = $Matches[4]
        if ($SubscriptionId -and $SubscriptionId -ne $projectSubscriptionId) {
            Write-Warn "AZURE_SUBSCRIPTION_ID ($SubscriptionId) differs from AZURE_AI_PROJECT_ID subscription ($projectSubscriptionId); using AZURE_SUBSCRIPTION_ID for roleDefinitionId."
        }
    } else {
        Write-Warn "AZURE_AI_PROJECT_ID format unexpected; falling back to endpoint + AZURE_RESOURCE_GROUP."
    }
}
if (-not $FoundryResourceGroup) {
    Write-Err "缺 Foundry resource group: set AZURE_AI_PROJECT_ID or AZURE_RESOURCE_GROUP."
    exit 1
}
if (-not $AcrResourceGroup) { $AcrResourceGroup = $FoundryResourceGroup }

Write-Info "agent     = $AgentName"
Write-Info "account   = $accountName"
Write-Info "project   = $projectName"
Write-Info "acr       = $AcrName"
Write-Info "foundryRg = $FoundryResourceGroup"
Write-Info "acrRg     = $AcrResourceGroup"

# ---------------------------------------------------------------------------
# 2. Acquire tokens (no az/azd needed)
# ---------------------------------------------------------------------------
function New-OAuthToken {
    param([string]$Scope)
    (Invoke-RestMethod -Method POST `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{
            client_id     = $ClientId
            client_secret = $ClientSecret
            scope         = $Scope
            grant_type    = 'client_credentials'
        } -TimeoutSec 30).access_token
}

$armToken = New-OAuthToken 'https://management.azure.com/.default'
$aiToken  = New-OAuthToken 'https://ai.azure.com/.default'
Write-Ok "Tokens acquired (arm + ai)"

# ---------------------------------------------------------------------------
# 3. Look up the agent's per-version MIs (instance_identity + blueprint)
# ---------------------------------------------------------------------------
$agentUrl = "$Endpoint/agents/$AgentName" + "?api-version=$ApiVersion"
try {
    $agent = Invoke-RestMethod -Uri $agentUrl -Headers @{ Authorization = "Bearer $aiToken" } -TimeoutSec 30
} catch {
    Write-Err "GET $agentUrl failed: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
    exit 1
}
$instancePid  = $agent.versions.latest.instance_identity.principal_id
$blueprintPid = $agent.versions.latest.blueprint.principal_id
$agentVersion = $agent.versions.latest.version
if (-not $instancePid -or -not $blueprintPid) {
    Write-Err "Could not find instance_identity / blueprint principalIds on latest version"
    exit 1
}
Write-Ok "Found per-version MIs (v$agentVersion): instance=$instancePid blueprint=$blueprintPid"

# ---------------------------------------------------------------------------
# 4. Idempotent role assignment helper
# ---------------------------------------------------------------------------
function Grant-Role {
    param(
        [string]$Scope,
        [string]$PrincipalId,
        [string]$RoleId,
        [string]$Label
    )
    $guid = [Guid]::NewGuid().ToString()
    $url = "https://management.azure.com${Scope}/providers/Microsoft.Authorization/roleAssignments/${guid}?api-version=2022-04-01"
    $body = @{ properties = @{
        roleDefinitionId = "/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/roleDefinitions/$RoleId"
        principalId      = $PrincipalId
        principalType    = "ServicePrincipal"
    } } | ConvertTo-Json
    try {
        Invoke-RestMethod -Method PUT -Uri $url -Headers @{ Authorization = "Bearer $armToken" } -ContentType "application/json" -Body $body -TimeoutSec 30 | Out-Null
        Write-Ok "$Label : granted"
    } catch {
        $msg = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
        if ($msg -match 'RoleAssignmentExists') {
            Write-Info "$Label : already exists (skip)"
        } else {
            Write-Err "$Label : $msg"
            $script:hadFailure = $true
        }
    }
}

# ---------------------------------------------------------------------------
# 5. Grant the four runtime roles
# ---------------------------------------------------------------------------
$script:hadFailure = $false
$acrScope     = "/subscriptions/$SubscriptionId/resourceGroups/$AcrResourceGroup/providers/Microsoft.ContainerRegistry/registries/$AcrName"
$accountScope = "/subscriptions/$SubscriptionId/resourceGroups/$FoundryResourceGroup/providers/Microsoft.CognitiveServices/accounts/$accountName"
$projectScope = "$accountScope/projects/$projectName"

Grant-Role -Scope $acrScope     -PrincipalId $instancePid  -RoleId $ACR_PULL_ROLE_ID       -Label "AcrPull        on ACR     -> instance"
Grant-Role -Scope $acrScope     -PrincipalId $blueprintPid -RoleId $ACR_PULL_ROLE_ID       -Label "AcrPull        on ACR     -> blueprint"
Grant-Role -Scope $accountScope -PrincipalId $instancePid  -RoleId $AZURE_AI_USER_ROLE_ID  -Label "Azure AI User  on account -> instance"
Grant-Role -Scope $projectScope -PrincipalId $instancePid  -RoleId $AZURE_AI_USER_ROLE_ID  -Label "Azure AI User  on project -> instance"

if ($script:hadFailure) {
    Write-Err "One or more grants failed — see errors above."
    exit 2
}
Write-Ok "All runtime roles granted. Agent runtime should now be reachable."
# Explicit success: `azd env get-value` calls in Resolve-Var can leave $LASTEXITCODE=1
# for missing keys, which would otherwise propagate to the azd hook runner.
exit 0
