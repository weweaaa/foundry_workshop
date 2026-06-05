<#
.SYNOPSIS
    azd prepackage hook: render agent.yaml + agent.manifest.yaml from .tpl files,
    substituting ${STUDENT_SUFFIX} so each student gets a uniquely-named hosted agent.

.DESCRIPTION
    The azd `azure.ai.agents` extension validates the `name` field against a strict
    regex BEFORE azd's own `${VAR}` substitution runs, so a literal `${STUDENT_SUFFIX}`
    in `agent.yaml` fails with:

        agent.yaml is not valid: template.name not in valid format

    Workaround: ship `agent.yaml.tpl` / `agent.manifest.yaml.tpl` in git, and pre-render
    them here. The other `${VAR}` references (AZURE_AI_PROJECT_ENDPOINT, etc.) are left
    untouched — azd substitutes those later during deploy.

    Resolution order for STUDENT_SUFFIX: -StudentSuffix > process env > workshop .env
    > `azd env get-value`. Same pattern as scripts/Windows/grant-agent-runtime-roles.ps1.

    Idempotent: safe to re-run.

.EXAMPLE
    # Manual run from Lab-2-vibe-coding dir:
    pwsh ./hooks/render-agent-yaml.ps1

    # Or wired via `services.research-agent.hooks.prepackage` in azure.yaml —
    # fires before every `azd package` / `azd deploy`.
#>
[CmdletBinding()]
param(
    [string]$StudentSuffix,
    [string]$EnvFile
)

$ErrorActionPreference = 'Stop'

function Write-Info { param([string]$m) Write-Host "ℹ️  $m" -ForegroundColor Cyan }
function Write-Ok   { param([string]$m) Write-Host "✅ $m" -ForegroundColor Green }
function Write-Err  { param([string]$m) Write-Host "❌ $m" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 1. Resolve config: param > process env > workshop .env > azd env
# ---------------------------------------------------------------------------
$labRoot      = Split-Path -Parent $PSScriptRoot          # ...\Lab-2-vibe-coding
$workshopRoot = Split-Path -Parent $labRoot               # ...\foundry_workshop
if (-not $EnvFile) { $EnvFile = Join-Path $workshopRoot '.env' }

$envFromFile = @{}
if (Test-Path -LiteralPath $EnvFile) {
    Get-Content -LiteralPath $EnvFile | ForEach-Object {
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

$StudentSuffix = Resolve-Var $StudentSuffix 'STUDENT_SUFFIX'
if (-not $StudentSuffix) {
    Write-Err "STUDENT_SUFFIX not set. Add it to $EnvFile, or run: azd env set STUDENT_SUFFIX <stuNNN>"
    exit 1
}

# Validate the suffix produces a legal agent name.
# Full name = "research-agent-<suffix>" (15-char prefix), max length 63.
# Agent name regex: ^[A-Za-z0-9][-A-Za-z0-9]{0,61}[A-Za-z0-9]$
# So suffix must be 1..48 chars, alphanumeric + dashes, no leading/trailing dash.
if ($StudentSuffix -notmatch '^[A-Za-z0-9]([-A-Za-z0-9]{0,46}[A-Za-z0-9])?$') {
    Write-Err "STUDENT_SUFFIX '$StudentSuffix' produces an invalid agent name. Must be 1-48 chars, alphanumeric + dashes, no leading/trailing dash."
    exit 1
}

Write-Info "STUDENT_SUFFIX = $StudentSuffix  (agent name will be: research-agent-$StudentSuffix)"

# ---------------------------------------------------------------------------
# 2. Render templates
# ---------------------------------------------------------------------------
$agentDir = Join-Path (Join-Path $labRoot 'src') 'research_agent'
$pairs = @(
    @{ Tpl = 'agent.yaml.tpl';          Out = 'agent.yaml' },
    @{ Tpl = 'agent.manifest.yaml.tpl'; Out = 'agent.manifest.yaml' }
)

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
foreach ($p in $pairs) {
    $tplPath = Join-Path $agentDir $p.Tpl
    $outPath = Join-Path $agentDir $p.Out
    if (-not (Test-Path -LiteralPath $tplPath)) {
        Write-Err "Template not found: $tplPath"
        exit 1
    }
    # Read as UTF-8 explicitly — Get-Content -Raw uses ANSI on Windows PowerShell 5.1
    # which would corrupt non-ASCII (CJK) characters when re-written as UTF-8.
    $tpl = [System.IO.File]::ReadAllText($tplPath, [System.Text.Encoding]::UTF8)
    $rendered = $tpl -replace [regex]::Escape('${STUDENT_SUFFIX}'), $StudentSuffix
    [System.IO.File]::WriteAllText($outPath, $rendered, $utf8NoBom)
    Write-Ok "rendered $($p.Out)"
}
