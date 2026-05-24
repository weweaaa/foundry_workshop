#!/usr/bin/env bash
#
# chat-hosted.sh
# ---------------
# 打开本地图形化 chat UI, 跟 Lab 1/3 部署的 hosted agent 聊天 (api-key 模式)。
#
# 不依赖 az/azd CLI, 不依赖 AAD/SP/OAuth2 — 用 Foundry account-level API key 直接调 hosted agent。
#
# 流程:
#   1. 从 .env / 进程 env / azd env 读 FOUNDRY_API_KEY + endpoint + agent name
#   2. 把这三项编码进 URL #cfg= (base64-json)
#   3. 在默认浏览器中打开 scripts/chat-hosted/index.html
#
# 凭据来源优先级 (越靠前优先级越高):
#   1. 命令行参数 --api-key / --endpoint / --agent-name
#   2. 进程环境变量 FOUNDRY_API_KEY / AZURE_AI_PROJECT_ENDPOINT / AGENT_NAME
#   3. workshop 根 .env (KEY=VALUE 行)
#   4. azd env (azd env get-value <KEY>) — 仅当 azd 已装并在 azd env 目录里跑
#
# 用法:
#   ./scripts/macOSLinux/chat-hosted.sh
#   ./scripts/macOSLinux/chat-hosted.sh --agent-name research-agent-stu07
#   ./scripts/macOSLinux/chat-hosted.sh --no-open    # 只打印 URL, 不开浏览器
#
# 依赖: curl, jq, base64, (macOS: open / Linux: xdg-open)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_VERSION='2025-11-15-preview'

AGENT_NAME=""; API_KEY_ARG=""; ENDPOINT_ARG=""; ENV_FILE=""; NO_OPEN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent-name) AGENT_NAME="$2"; shift 2 ;;
        --api-key)    API_KEY_ARG="$2"; shift 2 ;;
        --endpoint)   ENDPOINT_ARG="$2"; shift 2 ;;
        --env-file)   ENV_FILE="$2"; shift 2 ;;
        --no-open)    NO_OPEN=true; shift ;;
        -h|--help)    sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 64 ;;
    esac
done

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ 需要 jq (brew install jq / apt-get install jq)" >&2; exit 127
fi

c_red='\033[31m'; c_grn='\033[32m'; c_yel='\033[33m'; c_cyn='\033[36m'; c_gry='\033[90m'; c_rst='\033[0m'
info()  { printf "${c_cyn}ℹ️  %s${c_rst}\n" "$*"; }
warn2() { printf "${c_yel}⚠️  %s${c_rst}\n" "$*"; }
ok()    { printf "${c_grn}✅ %s${c_rst}\n" "$*"; }
err()   { printf "${c_red}❌ %s${c_rst}\n" "$*"; }

# ---- .env lookup (bash 3.2-compatible) ----
[[ -z "$ENV_FILE" ]] && ENV_FILE="$SCRIPT_DIR/../../.env"
_env_file_lookup() {
    local name="$1" file="$2"
    [[ -f "$file" ]] || return 0
    awk -v key="$name" '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        {
            line = $0
            eq = index(line, "=")
            if (eq < 2) next
            k = substr(line, 1, eq-1)
            v = substr(line, eq+1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            if (k != key) next
            if (length(v) >= 2) {
                first = substr(v, 1, 1); last = substr(v, length(v), 1)
                if ((first == "\"" && last == "\"") || (first == "\x27" && last == "\x27")) {
                    v = substr(v, 2, length(v)-2)
                }
            }
            print v
            exit
        }
    ' "$file"
}
_env_file_count() {
    local file="$1"
    [[ -f "$file" ]] || { echo 0; return; }
    awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        { if (index($0, "=") > 1) n++ }
        END { print n+0 }
    ' "$file"
}
if [[ -f "$ENV_FILE" ]]; then
    info "从 $ENV_FILE 读到 $(_env_file_count "$ENV_FILE") 个变量"
fi

resolve_var() {
    local param="$1" name="$2"
    if [[ -n "$param" ]]; then echo "$param"; return; fi
    local proc="${!name-}"
    if [[ -n "$proc" ]]; then echo "$proc"; return; fi
    local file_val
    file_val=$(_env_file_lookup "$name" "$ENV_FILE")
    if [[ -n "$file_val" ]]; then echo "$file_val"; return; fi
    if command -v azd >/dev/null 2>&1; then
        local azd_val
        azd_val=$(azd env get-value "$name" 2>/dev/null | tr -d '\r' | head -n1 || true)
        if [[ -n "$azd_val" && "$azd_val" != ERROR* ]]; then echo "$azd_val"; return; fi
    fi
    echo ""
}

API_KEY=$(resolve_var "$API_KEY_ARG" 'FOUNDRY_API_KEY')
ENDPOINT=$(resolve_var "$ENDPOINT_ARG" 'AZURE_AI_PROJECT_ENDPOINT')
if [[ -z "$AGENT_NAME" ]]; then
    AGENT_NAME=$(resolve_var "" 'AGENT_NAME')
    if [[ -z "$AGENT_NAME" ]]; then
        SUFFIX=$(resolve_var "" 'STUDENT_SUFFIX')
        if [[ -n "$SUFFIX" ]]; then AGENT_NAME="research-agent-$SUFFIX"; else AGENT_NAME="research-agent"; fi
    fi
fi

missing=()
[[ -z "$API_KEY" ]]  && missing+=('FOUNDRY_API_KEY')
[[ -z "$ENDPOINT" ]] && missing+=('AZURE_AI_PROJECT_ENDPOINT')
if [[ ${#missing[@]} -gt 0 ]]; then
    err "缺以下变量: ${missing[*]}"
    printf "${c_gry}   填到 workshop 根 .env 里, 或显式传 --api-key / --endpoint 参数。${c_rst}\n"
    printf "${c_gry}   .env 例:${c_rst}\n"
    printf "${c_gry}     AZURE_AI_PROJECT_ENDPOINT=https://<account>.services.ai.azure.com/api/projects/<project>${c_rst}\n"
    printf "${c_gry}     FOUNDRY_API_KEY=<讲师下发的 Foundry account key>${c_rst}\n"
    exit 1
fi

info "endpoint = $ENDPOINT"
info "agent    = $AGENT_NAME"
info "auth     = api-key (Foundry account key, ${#API_KEY} chars)"

# ---- build cfg JSON + base64 fragment ----
cfg_json=$(jq -nc \
    --arg endpoint "$ENDPOINT" \
    --arg agent    "$AGENT_NAME" \
    --arg apiKey   "$API_KEY" \
    '{endpoint:$endpoint, agent:$agent, apiKey:$apiKey, store:false}')

# base64 without line wraps (BSD vs GNU base64): pipe through tr to strip newlines.
b64=$(printf '%s' "$cfg_json" | base64 | tr -d '\n')

# URL-encode the base64 (replace + / =)
cfg_fragment=$(printf '%s' "$b64" | sed -e 's/+/%2B/g' -e 's/\//%2F/g' -e 's/=/%3D/g')

HTML_PATH="$SCRIPT_DIR/../chat-hosted/index.html"
if [[ ! -f "$HTML_PATH" ]]; then
    err "找不到 $HTML_PATH。仓库被改坏了?"
    exit 1
fi
ABS_HTML="$(cd "$(dirname "$HTML_PATH")" && pwd)/$(basename "$HTML_PATH")"
FILE_URI="file://${ABS_HTML}#cfg=${cfg_fragment}"

echo
ok "Chat UI URL (含 api-key, 不要分享):"
printf "${c_gry}    %s${c_rst}\n" "$FILE_URI"
echo

if [[ "$NO_OPEN" == "true" ]]; then
    info "(--no-open) 复制上面 URL 到浏览器里打开即可。"
    exit 0
fi

if command -v open >/dev/null 2>&1; then
    if open "$FILE_URI"; then ok "已在默认浏览器中打开。api-key 不过期, URL 反复用即可。"; else warn2 "open 失败, 请手动粘 URL"; fi
elif command -v xdg-open >/dev/null 2>&1; then
    if xdg-open "$FILE_URI" >/dev/null 2>&1; then ok "已在默认浏览器中打开。api-key 不过期, URL 反复用即可。"; else warn2 "xdg-open 失败, 请手动粘 URL"; fi
else
    warn2 "没找到 open / xdg-open, 请手动把上面 URL 粘到浏览器。"
fi
