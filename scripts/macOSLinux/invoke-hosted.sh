#!/usr/bin/env bash
#
# invoke-hosted.sh
# -----------------
# 命令行调用 hosted Foundry agent (Lab 1/3 验证, Lab 4 trace 来源)。
#
# 用 Foundry api-key (header) 直接调 /responses, 不依赖 az / azd / AAD / SP / OAuth2。
# 默认 store=true: response 写进 Foundry 内置存储 (Lab 4 dashboard 后续按 ID 拉详情)。
# 每次调用把 {response_id, agent_name, started_at, prompt, store} 追加到
# Lab-4-observability/data/responses.jsonl (一行一条) 作为 Lab 4 trace 索引。
#
# 凭据来源优先级: 显式参数 > 进程 env > workshop 根 .env
#
# 用法:
#   ./scripts/macOSLinux/invoke-hosted.sh --agent-name research-agent-stu05 --prompt "ping"
#   ./scripts/macOSLinux/invoke-hosted.sh --agent-name research-agent-stu05 --status-only
#   ./scripts/macOSLinux/invoke-hosted.sh --no-store --prompt "no trace please"
#
# 依赖: curl, jq

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_VERSION='2025-11-15-preview'

AGENT_NAME=""
PROMPT="Hello, who are you?"
STATUS_ONLY=false
NO_STORE=false
API_KEY_ARG=""; ENDPOINT_ARG=""; ENV_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent-name) AGENT_NAME="$2"; shift 2 ;;
        --prompt)     PROMPT="$2"; shift 2 ;;
        --status-only) STATUS_ONLY=true; shift ;;
        --no-store)   NO_STORE=true; shift ;;
        --api-key)    API_KEY_ARG="$2"; shift 2 ;;
        --endpoint)   ENDPOINT_ARG="$2"; shift 2 ;;
        --env-file)   ENV_FILE="$2"; shift 2 ;;
        -h|--help)    sed -n '2,22p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 64 ;;
    esac
done

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ 需要 jq (brew install jq / apt-get install jq)" >&2; exit 127
fi

c_red='\033[31m'; c_grn='\033[32m'; c_yel='\033[33m'; c_cyn='\033[36m'; c_gry='\033[90m'; c_rst='\033[0m'

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
resolve_var() {
    local param="$1" name="$2"
    if [[ -n "$param" ]]; then echo "$param"; return; fi
    local proc="${!name-}"
    if [[ -n "$proc" ]]; then echo "$proc"; return; fi
    _env_file_lookup "$name" "$ENV_FILE"
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
    printf "${c_red}❌ 缺以下变量: %s — 请把 .env.example 复制成 .env 并填好。${c_rst}\n" "${missing[*]}"
    exit 1
fi

RESPONSES_URL="$ENDPOINT/agents/$AGENT_NAME/endpoint/protocols/openai/responses?api-version=$API_VERSION"

if [[ "$STATUS_ONLY" == "true" ]]; then
    url="$ENDPOINT/agents/$AGENT_NAME?api-version=$API_VERSION"
    http=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -H "api-key: $API_KEY" "$url" || echo 000)
    if [[ "$http" =~ ^2 ]]; then
        printf "${c_grn}status=Reachable, http=%s, agent=%s${c_rst}\n" "$http" "$AGENT_NAME"
        exit 0
    else
        printf "${c_red}status=Unreachable, http=%s, agent=%s${c_rst}\n" "$http" "$AGENT_NAME"
        exit 2
    fi
fi

STORE=true
[[ "$NO_STORE" == "true" ]] && STORE=false

BODY=$(jq -nc --arg p "$PROMPT" --argjson s "$STORE" '{input:$p, store:$s}')

printf "${c_cyn}→ POST %s  (store=%s)${c_rst}\n" "$RESPONSES_URL" "$STORE"
printf "${c_gry}→ prompt: %s${c_rst}\n" "$PROMPT"

resp_file="$(mktemp -t invoke-hosted-XXXXXX)"
trap 'rm -f "$resp_file"' EXIT

http_code=$(curl -sS -o "$resp_file" -w '%{http_code}' --max-time 120 \
    -X POST "$RESPONSES_URL" \
    -H "api-key: $API_KEY" \
    -H "content-type: application/json; charset=utf-8" \
    --data-binary "$BODY" || echo 000)

if [[ ! "$http_code" =~ ^2 ]]; then
    printf "${c_red}❌ Invocation failed (HTTP %s)${c_rst}\n" "$http_code"
    if [[ -s "$resp_file" ]]; then
        printf "${c_yel}%s${c_rst}\n" "$(cat "$resp_file")"
    fi
    exit 3
fi

printf "\n${c_grn}--- Response ---${c_rst}\n"
jq '.' < "$resp_file"

if [[ "$STORE" == "true" ]]; then
    resp_id=$(jq -r '.id // empty' < "$resp_file")
    if [[ -n "$resp_id" ]]; then
        trace_dir="$SCRIPT_DIR/../../Lab-4-observability/data"
        mkdir -p "$trace_dir"
        jsonl="$trace_dir/responses.jsonl"
        started_at=$(date -u +"%Y-%m-%dT%H:%M:%S.%6NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
        jq -nc \
            --arg id "$resp_id" \
            --arg agent "$AGENT_NAME" \
            --arg started "$started_at" \
            --arg prompt "$PROMPT" \
            '{response_id:$id, agent_name:$agent, started_at:$started, prompt:$prompt, store:true}' \
            >> "$jsonl"
        printf "${c_gry}→ trace index → %s${c_rst}\n" "$jsonl"
    fi
fi
