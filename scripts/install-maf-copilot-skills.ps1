<#
.SYNOPSIS
    确保学员 VS Code 启用了 Copilot Chat 的 chatmode / instructions / prompt files。

.DESCRIPTION
    workshop 仓库的 `Lab-2-vibe-coding/.github/{chatmodes,instructions,prompts}/` 已经放好，
    本脚本仅:
        1. 检查 VS Code / Copilot 扩展存在；
        2. 写 .vscode/settings.json 启用相关 chat.* 设置；
        3. 打印每个 skill 的入口（哪个文件、Chat 里怎么触发）。

    幂等：可以重跑。
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

function Test-Command {
    param([string]$Name)
    $null = Get-Command $Name -ErrorAction SilentlyContinue
    return $?
}

# 切到 Lab-2-vibe-coding 目录 (chatmodes / prompts 在那)
$trackA = Join-Path $WorkspaceRoot 'Lab-2-vibe-coding'
if (-not (Test-Path $trackA)) {
    throw "找不到 $trackA。请把脚本放在 workshop/scripts/ 下并从 workshop/ 目录跑。"
}

Write-Host "==> 检查 VS Code" -ForegroundColor Cyan
if (-not (Test-Command 'code')) {
    Write-Host "⚠  未检测到 'code' 命令。请先装 VS Code 并在 PATH 中暴露 'code'。" -ForegroundColor Yellow
} else {
    code --version | Select-Object -First 1 | Out-Host
}

Write-Host "==> 检查 GitHub Copilot 扩展" -ForegroundColor Cyan
if (Test-Command 'code') {
    $exts = code --list-extensions 2>$null
    $hasCopilot     = $exts -contains 'github.copilot'
    $hasCopilotChat = $exts -contains 'github.copilot-chat'
    if (-not $hasCopilot)     { Write-Host "❌ 缺扩展 github.copilot；运行: code --install-extension github.copilot" -ForegroundColor Red }
    if (-not $hasCopilotChat) { Write-Host "❌ 缺扩展 github.copilot-chat；运行: code --install-extension github.copilot-chat" -ForegroundColor Red }
    if ($hasCopilot -and $hasCopilotChat) { Write-Host "✅ GitHub Copilot + Chat 已安装" -ForegroundColor Green }
}

# 写 .vscode/settings.json
$vscodeDir = Join-Path $trackA '.vscode'
$settingsPath = Join-Path $vscodeDir 'settings.json'
New-Item -ItemType Directory -Force -Path $vscodeDir | Out-Null

$current = @{}
if (Test-Path $settingsPath) {
    try {
        $raw = Get-Content $settingsPath -Raw
        if ($raw.Trim()) { $current = $raw | ConvertFrom-Json -AsHashtable }
    } catch {
        Write-Host "⚠  现有 settings.json 解析失败，将覆盖。" -ForegroundColor Yellow
    }
}
if (-not $current) { $current = @{} }
$current['chat.promptFiles']       = $true
$current['chat.modeFilesLocations'] = @{ '.github/chatmodes' = $true }
$current['chat.instructionsFilesLocations'] = @{ '.github/instructions' = $true }
$current['chat.promptFilesLocations']       = @{ '.github/prompts' = $true }

$json = $current | ConvertTo-Json -Depth 10
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($settingsPath, $json, $utf8NoBom)
Write-Host "✅ 写入 $settingsPath" -ForegroundColor Green

# 打印 skill 入口
Write-Host "`n==> 已就绪的 Copilot skills" -ForegroundColor Cyan
$skills = @(
    @{ Type = 'chatmode';     Path = 'Lab-2-vibe-coding/.github/chatmodes/maf-agent.chatmode.md';        Trigger = 'Copilot Chat 顶部下拉 → "maf-agent"' },
    @{ Type = 'instructions'; Path = 'Lab-2-vibe-coding/.github/instructions/maf-tools.instructions.md'; Trigger = '编辑 tools/**/*.py 时自动注入' },
    @{ Type = 'instructions'; Path = 'Lab-2-vibe-coding/.github/instructions/maf-personas.instructions.md'; Trigger = '编辑 personas/**/*.md 时自动注入' },
    @{ Type = 'instructions'; Path = 'Lab-2-vibe-coding/.github/instructions/maf-skills.instructions.md'; Trigger = '编辑 skills/**/SKILL.md 时自动注入' },
    @{ Type = 'prompt';       Path = 'Lab-2-vibe-coding/.github/prompts/persona.prompt.md'; Trigger = 'Chat 输入 /persona' },
    @{ Type = 'prompt';       Path = 'Lab-2-vibe-coding/.github/prompts/skill.prompt.md';   Trigger = 'Chat 输入 /skill' },
    @{ Type = 'prompt';       Path = 'Lab-2-vibe-coding/.github/prompts/tool.prompt.md';    Trigger = 'Chat 输入 /tool' },
    @{ Type = 'prompt';       Path = 'Lab-2-vibe-coding/.github/prompts/deploy.prompt.md';  Trigger = 'Chat 输入 /deploy' }
)
foreach ($s in $skills) {
    $exists = Test-Path (Join-Path $WorkspaceRoot $s.Path)
    $mark = if ($exists) { '✅' } else { '❌' }
    Write-Host ("  {0} [{1,-13}] {2}" -f $mark, $s.Type, $s.Trigger)
    Write-Host ("       {0}" -f $s.Path) -ForegroundColor DarkGray
}

Write-Host "`n下一步:" -ForegroundColor Yellow
Write-Host "  1. 重新加载 VS Code: 在 Command Palette 跑 'Developer: Reload Window'"
Write-Host "  2. 打开 Copilot Chat (Ctrl+Alt+I)，确认顶部下拉里能看到 'maf-agent'"
Write-Host "  3. 输入 /persona / /tool / /skill / /deploy 试试斜杠命令"
