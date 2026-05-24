<#
.SYNOPSIS
    把 workshop 根的 .env 加载到当前 PowerShell 进程的环境变量里。

.DESCRIPTION
    所有 Lab 都从同一份 .env 读凭据 (学员只填一次)。
    脚本约定查找顺序:
      1. 显式 -Path
      2. $PSScriptRoot\..\..\.env (workshop 根, 默认)

    用法 (在任意 Lab 子目录里):
      . ..\scripts\Windows\load-env.ps1                  # dot-source 让变量进当前 shell
      ..\scripts\Windows\load-env.ps1                    # 子进程方式 (变量进 Process 域, 当前 shell 也能看到)

    任何 chat-hosted.ps1 / invoke-hosted.ps1 / sanity-check.ps1 在被调时
    会自动尝试 load 一次, 学员一般不需要手动跑此脚本。

.EXAMPLE
    cd Lab-2-vibe-coding
    . ..\scripts\Windows\load-env.ps1
    python -m src.research_agent.main
#>
[CmdletBinding()]
param(
    [string]$Path
)

if (-not $Path) {
    $Path = Join-Path $PSScriptRoot '..\..\.env'
}

if (-not (Test-Path $Path)) {
    Write-Host "⚠️  .env not found at $Path. Copy .env.example to .env and fill in." -ForegroundColor Yellow
    return
}

$count = 0
Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $eq = $line.IndexOf('=')
    if ($eq -lt 1) { return }
    $k = $line.Substring(0, $eq).Trim()
    $v = $line.Substring($eq + 1).Trim().Trim('"').Trim("'")
    # Expand simple ${VAR} references against already-loaded values (single pass).
    while ($v -match '\$\{([A-Za-z_][A-Za-z0-9_]*)\}') {
        $name = $matches[1]
        $val  = [Environment]::GetEnvironmentVariable($name, 'Process')
        if (-not $val) { break }
        $v = $v -replace ("\$\{" + [regex]::Escape($name) + "\}"), $val
    }
    [Environment]::SetEnvironmentVariable($k, $v, 'Process')
    $count++
}

Write-Host "✅ loaded $count vars from $Path" -ForegroundColor Green
