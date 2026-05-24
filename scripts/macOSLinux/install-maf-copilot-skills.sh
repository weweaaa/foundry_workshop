#!/usr/bin/env bash
#
# install-maf-copilot-skills.sh
# -------------------------------
# 确保学员 VS Code 启用了 Copilot Chat 的 chatmode / instructions / prompt files。
#
# workshop 仓库的 Lab-2-vibe-coding/.github/{chatmodes,instructions,prompts}/ 已经放好,
# 本脚本仅:
#   1. 检查 VS Code / Copilot 扩展存在
#   2. 写 Lab-2-vibe-coding/.vscode/settings.json 启用相关 chat.* 设置
#   3. 打印每个 skill 的入口 (哪个文件、Chat 里怎么触发)
#
# 幂等: 可以反复跑。
#
# 用法:
#   ./scripts/macOSLinux/install-maf-copilot-skills.sh
#   ./scripts/macOSLinux/install-maf-copilot-skills.sh --workspace-root /path/to/foundry_workshop
#
# 依赖: jq, code (PATH 中有 'code' 命令)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --workspace-root) WORKSPACE_ROOT="$2"; shift 2 ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 64 ;;
    esac
done

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ 需要 jq (brew install jq / apt-get install jq)" >&2; exit 127
fi

c_red='\033[31m'; c_grn='\033[32m'; c_yel='\033[33m'; c_cyn='\033[36m'; c_gry='\033[90m'; c_rst='\033[0m'

TRACK_A="$WORKSPACE_ROOT/Lab-2-vibe-coding"
if [[ ! -d "$TRACK_A" ]]; then
    printf "${c_red}❌ 找不到 %s。请把脚本放在 workshop/scripts/ 下并从 workshop/ 目录跑。${c_rst}\n" "$TRACK_A" >&2
    exit 1
fi

printf "${c_cyn}==> 检查 VS Code${c_rst}\n"
if ! command -v code >/dev/null 2>&1; then
    printf "${c_yel}⚠  未检测到 'code' 命令。请先装 VS Code 并在 PATH 中暴露 'code'。${c_rst}\n"
else
    code --version | head -n1
fi

printf "${c_cyn}==> 检查 GitHub Copilot 扩展${c_rst}\n"
if command -v code >/dev/null 2>&1; then
    exts=$(code --list-extensions 2>/dev/null || true)
    has_copilot=false; has_copilot_chat=false
    echo "$exts" | grep -qx 'github.copilot'      && has_copilot=true
    echo "$exts" | grep -qx 'github.copilot-chat' && has_copilot_chat=true
    [[ "$has_copilot" == "false" ]]      && printf "${c_red}❌ 缺扩展 github.copilot;      运行: code --install-extension github.copilot${c_rst}\n"
    [[ "$has_copilot_chat" == "false" ]] && printf "${c_red}❌ 缺扩展 github.copilot-chat; 运行: code --install-extension github.copilot-chat${c_rst}\n"
    if [[ "$has_copilot" == "true" && "$has_copilot_chat" == "true" ]]; then
        printf "${c_grn}✅ GitHub Copilot + Chat 已安装${c_rst}\n"
    fi
fi

# ---- write .vscode/settings.json (merge with existing) ----
VSCODE_DIR="$TRACK_A/.vscode"
SETTINGS_PATH="$VSCODE_DIR/settings.json"
mkdir -p "$VSCODE_DIR"

if [[ -f "$SETTINGS_PATH" ]] && jq empty "$SETTINGS_PATH" >/dev/null 2>&1; then
    current_json=$(cat "$SETTINGS_PATH")
else
    if [[ -f "$SETTINGS_PATH" ]]; then
        printf "${c_yel}⚠  现有 settings.json 解析失败, 将覆盖。${c_rst}\n"
    fi
    current_json='{}'
fi

merged=$(echo "$current_json" | jq '
    . + {
        "chat.promptFiles": true,
        "chat.modeFilesLocations":         {".github/chatmodes":    true},
        "chat.instructionsFilesLocations": {".github/instructions": true},
        "chat.promptFilesLocations":       {".github/prompts":      true}
    }')
printf '%s\n' "$merged" > "$SETTINGS_PATH"
printf "${c_grn}✅ 写入 %s${c_rst}\n" "$SETTINGS_PATH"

# ---- print skill entries ----
printf "\n${c_cyn}==> 已就绪的 Copilot skills${c_rst}\n"
print_skill() {
    local type="$1" relpath="$2" trigger="$3"
    local mark="❌"
    [[ -e "$WORKSPACE_ROOT/$relpath" ]] && mark="✅"
    printf "  %s [%-13s] %s\n" "$mark" "$type" "$trigger"
    printf "${c_gry}       %s${c_rst}\n" "$relpath"
}
print_skill chatmode     'Lab-2-vibe-coding/.github/chatmodes/maf-agent.chatmode.md'           'Copilot Chat 顶部下拉 → "maf-agent"'
print_skill instructions 'Lab-2-vibe-coding/.github/instructions/maf-tools.instructions.md'    '编辑 tools/**/*.py 时自动注入'
print_skill instructions 'Lab-2-vibe-coding/.github/instructions/maf-personas.instructions.md' '编辑 personas/**/*.md 时自动注入'
print_skill instructions 'Lab-2-vibe-coding/.github/instructions/maf-skills.instructions.md'   '编辑 skills/**/SKILL.md 时自动注入'
print_skill prompt       'Lab-2-vibe-coding/.github/prompts/persona.prompt.md'                 'Chat 输入 /persona'
print_skill prompt       'Lab-2-vibe-coding/.github/prompts/skill.prompt.md'                   'Chat 输入 /skill'
print_skill prompt       'Lab-2-vibe-coding/.github/prompts/tool.prompt.md'                    'Chat 输入 /tool'
print_skill prompt       'Lab-2-vibe-coding/.github/prompts/deploy.prompt.md'                  'Chat 输入 /deploy'

printf "\n${c_yel}下一步:${c_rst}\n"
echo "  1. 重新加载 VS Code: 在 Command Palette 跑 'Developer: Reload Window'"
echo "  2. 打开 Copilot Chat (Cmd+Ctrl+I / Ctrl+Alt+I), 确认顶部下拉里能看到 'maf-agent'"
echo "  3. 输入 /persona / /tool / /skill / /deploy 试试斜杠命令"
