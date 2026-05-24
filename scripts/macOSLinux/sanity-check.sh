#!/usr/bin/env bash
#
# sanity-check.sh
# ----------------
# Workshop sanity check — 验证学员的 .env + 凭据 + 共享 Foundry 资源是否就绪。
#
# 在 Lab 0/1 后跑一次。**不依赖 az/azd CLI**, 直接用 .env 里的 Foundry api-key
# + ARM OAuth2 (SP) 跑只读 API:
#
#   1. .env 关键变量都已填
#   2. Foundry api-key 能调 /deployments  → 模型 deployment 存在
#   3. Foundry api-key 能调 /agents       → 学员的 hosted agent 可达
#   4. ARM token (SP) 能跑 ACR /listBuildSourceUploadUrl → AcrPush 权限就绪
#
# 用法:
#   ./scripts/macOSLinux/sanity-check.sh
#   ./scripts/macOSLinux/sanity-check.sh --expected-agent research-agent-stu07
#
# 依赖: curl, jq

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_VERSION='2025-11-15-preview'

EXPECTED_AGENT=""
ENV_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --expected-agent) EXPECTED_AGENT="$2"; shift 2 ;;
        --env-file)       ENV_FILE="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 64 ;;
    esac
done

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ 需要 jq, 请先安装 (brew install jq / apt-get install jq)" >&2
    exit 127
fi

c_red='\033[31m'; c_grn='\033[32m'; c_yel='\033[33m'; c_cyn='\033[36m'; c_gry='\033[90m'; c_rst='\033[0m'

write_result() {
    local label="$1" pass="$2" detail="${3:-}"
    if [[ "$pass" == "true" ]]; then
        printf "${c_grn}✅ %s${c_rst}\n" "$label"
        [[ -n "$detail" ]] && printf "${c_gry}   %s${c_rst}\n" "$detail"
    else
        printf "${c_red}❌ %s${c_rst}\n" "$label"
        [[ -n "$detail" ]] && printf "${c_yel}   %s${c_rst}\n" "$detail"
    fi
}

printf "\n${c_cyn}=== Workshop Sanity Check ===${c_rst}\n\n"

# ---- .env lookup (bash 3.2-compatible, no associative arrays) ----
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
    local name="$1"
    local proc="${!name-}"
    if [[ -n "$proc" ]]; then echo "$proc"; return; fi
    _env_file_lookup "$name" "$ENV_FILE"
}

endpoint=$(resolve_var 'AZURE_AI_PROJECT_ENDPOINT')
model=$(resolve_var 'AZURE_AI_MODEL_DEPLOYMENT_NAME')
suffix=$(resolve_var 'STUDENT_SUFFIX')
acr_name=$(resolve_var 'AZURE_CONTAINER_REGISTRY_NAME')
api_key=$(resolve_var 'FOUNDRY_API_KEY')
client_id=$(resolve_var 'AZURE_CLIENT_ID')
secret=$(resolve_var 'AZURE_CLIENT_SECRET')
tenant_id=$(resolve_var 'AZURE_TENANT_ID')
sub_id=$(resolve_var 'AZURE_SUBSCRIPTION_ID')

bool() { [[ -n "$1" ]] && echo "true" || echo "false"; }

write_result ".env: AZURE_AI_PROJECT_ENDPOINT"      "$(bool "$endpoint")"  "$endpoint"
write_result ".env: AZURE_AI_MODEL_DEPLOYMENT_NAME" "$(bool "$model")"     "$model"
write_result ".env: STUDENT_SUFFIX"                 "$(bool "$suffix")"    "$suffix"
write_result ".env: AZURE_CONTAINER_REGISTRY_NAME"  "$(bool "$acr_name")"  "$acr_name"
write_result ".env: FOUNDRY_API_KEY"                "$(bool "$api_key")"
write_result ".env: AZURE_TENANT_ID"                "$(bool "$tenant_id")"
write_result ".env: AZURE_CLIENT_ID"                "$(bool "$client_id")"
write_result ".env: AZURE_CLIENT_SECRET"            "$(bool "$secret")"
write_result ".env: AZURE_SUBSCRIPTION_ID"          "$(bool "$sub_id")"

if [[ -z "$EXPECTED_AGENT" ]]; then
    if [[ -n "$suffix" ]]; then
        EXPECTED_AGENT="research-agent-$suffix"
    else
        EXPECTED_AGENT="research-agent"
    fi
fi

# ---- Foundry: deployments ----
if [[ -n "$endpoint" && -n "$model" && -n "$api_key" ]]; then
    body=$(curl -fsS --max-time 15 \
        -H "api-key: $api_key" \
        "$endpoint/deployments?api-version=2025-05-15-preview" 2>/dev/null) || body=""
    if [[ -n "$body" ]]; then
        count=$(echo "$body" | jq '[.value // .data // []] | flatten | length' 2>/dev/null || echo 0)
        found=$(echo "$body" | jq --arg m "$model" '
            [(.value // .data // [])[] | select(.name == $m or .id == $m)] | length > 0
        ' 2>/dev/null)
        write_result "模型 deployment '$model' 在共享 project 中" "${found:-false}" "items=$count"
    else
        write_result "模型 deployment '$model' 在共享 project 中" "false" "调 /deployments 失败"
    fi
else
    write_result "模型 deployment 在共享 project 中" "false" "缺前置 (endpoint/model/api-key)"
fi

# ---- Foundry: hosted agent /responses ping ----
if [[ -n "$endpoint" && -n "$api_key" ]]; then
    url="$endpoint/agents/$EXPECTED_AGENT/endpoint/protocols/openai/responses?api-version=$API_VERSION"
    body=$(curl -fsS --max-time 60 \
        -H "api-key: $api_key" -H "content-type: application/json" \
        -d '{"input":"ping","store":false}' "$url" 2>/dev/null) || body=""
    if [[ -n "$body" ]]; then
        status=$(echo "$body" | jq -r '.status // ""' 2>/dev/null)
        ok="false"; [[ "$status" == "completed" ]] && ok="true"
        write_result "Hosted agent '$EXPECTED_AGENT' 可达 + 跑通" "$ok" "status=$status"
    else
        write_result "Hosted agent '$EXPECTED_AGENT' 可达" "false" "调 /responses 失败"
    fi
else
    write_result "Hosted agent '$EXPECTED_AGENT' 可达" "false" "缺前置 (endpoint/api-key)"
fi

# ---- ARM (SP) → ACR push capability ----
if [[ -n "$acr_name" && -n "$client_id" && -n "$secret" && -n "$tenant_id" && -n "$sub_id" ]]; then
    token_resp=$(curl -fsS --max-time 30 \
        -X POST "https://login.microsoftonline.com/$tenant_id/oauth2/v2.0/token" \
        -H 'content-type: application/x-www-form-urlencoded' \
        --data-urlencode "client_id=$client_id" \
        --data-urlencode "client_secret=$secret" \
        --data-urlencode "scope=https://management.azure.com/.default" \
        --data-urlencode "grant_type=client_credentials" 2>/dev/null) || token_resp=""
    arm_token=$(echo "$token_resp" | jq -r '.access_token // empty' 2>/dev/null)

    if [[ -n "$arm_token" ]]; then
        acr_url="https://management.azure.com/subscriptions/$sub_id/resourceGroups/foundry-workshop/providers/Microsoft.ContainerRegistry/registries/$acr_name/listBuildSourceUploadUrl?api-version=2019-06-01-preview"
        resp=$(curl -fsS --max-time 15 -X POST -H "Authorization: Bearer $arm_token" "$acr_url" 2>/dev/null) || resp=""
        upload=$(echo "$resp" | jq -r '.uploadUrl // empty' 2>/dev/null)
        if [[ -n "$upload" ]]; then
            write_result "ACR '$acr_name' 可远程构建 (AcrPush + Contributor)" "true"
        else
            write_result "ACR '$acr_name' 可远程构建 (AcrPush + Contributor)" "false" "listBuildSourceUploadUrl 失败"
        fi
    else
        write_result "ACR '$acr_name' 可远程构建 (AcrPush + Contributor)" "false" "拿 ARM token 失败 — 检查 SP 凭据"
    fi
else
    write_result "ACR '$acr_name' 可远程构建" "false" "缺 ACR name 或 SP 凭据"
fi

printf "\n${c_cyn}如有 ❌, 把整段输出贴到助教频道。${c_rst}\n\n"
