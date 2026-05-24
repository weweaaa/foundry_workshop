#!/usr/bin/env bash
#
# grant-agent-runtime-roles.sh
# -----------------------------
# Workshop postdeploy hook: grant runtime roles to a Foundry hosted agent's per-version MIs.
#
# 每次 `azd deploy` 一个 hosted Foundry agent, Foundry 会给该版本拉两个 per-version MI
# (instance_identity + blueprint)。容器要拉镜像 + agent 代码要调 model deployment, 这俩 MI 需要:
#   AcrPull        on workshop ACR              — 拉镜像
#   Azure AI User  on Foundry account + project — DefaultAzureCredential 调 chat/completions
#
# 学员的 SP 持有 RG-scoped `User Access Administrator` (RBAC condition v2 约束: 只能给上面两个角色 ID
# 做 assign), 所以本脚本反复跑安全无害, 已存在的 assignment 会跳过。
#
# 全部读 `azd env get-value` + workshop 根 .env (不需要 az login)。幂等。
#
# 用法:
#   ./scripts/macOSLinux/grant-agent-runtime-roles.sh
#   ./scripts/macOSLinux/grant-agent-runtime-roles.sh --agent-name research-agent-stu05
#
# 或者把它接到 azure.yaml 的 hooks.postdeploy 里, 每次 azd deploy 后自动跑。
#
# 依赖: curl, jq, uuidgen (macOS 自带, Linux 通常 util-linux)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_VERSION='2025-11-15-preview'

# Built-in Azure RBAC role IDs
ACR_PULL_ROLE_ID='7f951dda-4ed3-4680-a7ca-43fe172d538d'
AZURE_AI_USER_ROLE_ID='53ca6127-db72-4b80-b1b0-d745d6d5456d'

AGENT_NAME=""; CLIENT_ID_ARG=""; CLIENT_SECRET_ARG=""; TENANT_ID_ARG=""
SUB_ID_ARG=""; ENDPOINT_ARG=""; ACR_NAME_ARG=""; ENV_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent-name)     AGENT_NAME="$2"; shift 2 ;;
        --client-id)      CLIENT_ID_ARG="$2"; shift 2 ;;
        --client-secret)  CLIENT_SECRET_ARG="$2"; shift 2 ;;
        --tenant-id)      TENANT_ID_ARG="$2"; shift 2 ;;
        --subscription)   SUB_ID_ARG="$2"; shift 2 ;;
        --endpoint)       ENDPOINT_ARG="$2"; shift 2 ;;
        --acr-name)       ACR_NAME_ARG="$2"; shift 2 ;;
        --api-version)    API_VERSION="$2"; shift 2 ;;
        --env-file)       ENV_FILE="$2"; shift 2 ;;
        -h|--help)        sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 64 ;;
    esac
done

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ 需要 jq (brew install jq / apt-get install jq)" >&2; exit 127
fi

c_red='\033[31m'; c_grn='\033[32m'; c_yel='\033[33m'; c_cyn='\033[36m'; c_rst='\033[0m'
info() { printf "${c_cyn}ℹ️  %s${c_rst}\n" "$*"; }
ok()   { printf "${c_grn}✅ %s${c_rst}\n" "$*"; }
warn() { printf "${c_yel}⚠️  %s${c_rst}\n" "$*"; }
err()  { printf "${c_red}❌ %s${c_rst}\n" "$*"; }

new_guid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        python3 -c 'import uuid;print(uuid.uuid4())'
    fi
}

# ---- resolve config: param > process env > .env > azd env (bash 3.2-compatible) ----
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

CLIENT_ID=$(resolve_var       "$CLIENT_ID_ARG"     'AZURE_CLIENT_ID')
CLIENT_SECRET=$(resolve_var   "$CLIENT_SECRET_ARG" 'AZURE_CLIENT_SECRET')
TENANT_ID=$(resolve_var       "$TENANT_ID_ARG"     'AZURE_TENANT_ID')
SUBSCRIPTION_ID=$(resolve_var "$SUB_ID_ARG"        'AZURE_SUBSCRIPTION_ID')
ENDPOINT=$(resolve_var        "$ENDPOINT_ARG"      'AZURE_AI_PROJECT_ENDPOINT')
ACR_NAME=$(resolve_var        "$ACR_NAME_ARG"      'AZURE_CONTAINER_REGISTRY_NAME')
if [[ -z "$AGENT_NAME" ]]; then
    AGENT_NAME=$(resolve_var "" 'AGENT_NAME')
    if [[ -z "$AGENT_NAME" ]]; then
        SUFFIX=$(resolve_var "" 'STUDENT_SUFFIX')
        if [[ -n "$SUFFIX" ]]; then AGENT_NAME="research-agent-$SUFFIX"; else AGENT_NAME="research-agent"; fi
    fi
fi

missing=()
[[ -z "$CLIENT_ID" ]]       && missing+=('AZURE_CLIENT_ID')
[[ -z "$CLIENT_SECRET" ]]   && missing+=('AZURE_CLIENT_SECRET')
[[ -z "$TENANT_ID" ]]       && missing+=('AZURE_TENANT_ID')
[[ -z "$SUBSCRIPTION_ID" ]] && missing+=('AZURE_SUBSCRIPTION_ID')
[[ -z "$ENDPOINT" ]]        && missing+=('AZURE_AI_PROJECT_ENDPOINT')
[[ -z "$ACR_NAME" ]]        && missing+=('AZURE_CONTAINER_REGISTRY_NAME')
if [[ ${#missing[@]} -gt 0 ]]; then
    err "缺以下变量: ${missing[*]}"
    exit 1
fi

# Endpoint format: https://<account>.services.ai.azure.com/api/projects/<project>
if [[ ! "$ENDPOINT" =~ ^https://([^.]+)\.services\.ai\.azure\.com/api/projects/([^/?#]+) ]]; then
    err "AZURE_AI_PROJECT_ENDPOINT format unexpected: $ENDPOINT"
    exit 1
fi
ACCOUNT_NAME="${BASH_REMATCH[1]}"
PROJECT_NAME="${BASH_REMATCH[2]}"

info "agent     = $AGENT_NAME"
info "account   = $ACCOUNT_NAME"
info "project   = $PROJECT_NAME"
info "acr       = $ACR_NAME"

# ---- Acquire tokens ----
get_oauth_token() {
    local scope="$1"
    curl -fsS --max-time 30 \
        -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
        -H 'content-type: application/x-www-form-urlencoded' \
        --data-urlencode "client_id=$CLIENT_ID" \
        --data-urlencode "client_secret=$CLIENT_SECRET" \
        --data-urlencode "scope=$scope" \
        --data-urlencode "grant_type=client_credentials" \
        | jq -r '.access_token // empty'
}

ARM_TOKEN=$(get_oauth_token 'https://management.azure.com/.default') || true
AI_TOKEN=$(get_oauth_token  'https://ai.azure.com/.default') || true

if [[ -z "$ARM_TOKEN" || -z "$AI_TOKEN" ]]; then
    err "无法获取 OAuth tokens — 检查 SP 凭据 (AZURE_CLIENT_ID/SECRET/TENANT_ID)"
    exit 1
fi
ok "Tokens acquired (arm + ai)"

# ---- Look up per-version MIs ----
agent_url="$ENDPOINT/agents/$AGENT_NAME?api-version=$API_VERSION"
agent_resp=$(curl -fsS --max-time 30 -H "Authorization: Bearer $AI_TOKEN" "$agent_url") || {
    err "GET $agent_url 失败"; exit 1; }

INSTANCE_PID=$(echo "$agent_resp"  | jq -r '.versions.latest.instance_identity.principal_id // empty')
BLUEPRINT_PID=$(echo "$agent_resp" | jq -r '.versions.latest.blueprint.principal_id // empty')
AGENT_VERSION=$(echo "$agent_resp" | jq -r '.versions.latest.version // empty')
if [[ -z "$INSTANCE_PID" || -z "$BLUEPRINT_PID" ]]; then
    err "找不到 instance_identity / blueprint principalIds (latest version)"
    exit 1
fi
ok "Found per-version MIs (v$AGENT_VERSION): instance=$INSTANCE_PID blueprint=$BLUEPRINT_PID"

# ---- Idempotent role assignment ----
HAD_FAILURE=0
grant_role() {
    local scope="$1" principal="$2" role_id="$3" label="$4"
    local guid; guid=$(new_guid)
    local url="https://management.azure.com${scope}/providers/Microsoft.Authorization/roleAssignments/${guid}?api-version=2022-04-01"
    local body
    body=$(jq -nc \
        --arg rdid "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/$role_id" \
        --arg pid  "$principal" \
        '{properties:{roleDefinitionId:$rdid, principalId:$pid, principalType:"ServicePrincipal"}}')

    local tmp; tmp=$(mktemp -t grant-role-XXXXXX)
    local http
    http=$(curl -sS -o "$tmp" -w '%{http_code}' --max-time 30 \
        -X PUT "$url" \
        -H "Authorization: Bearer $ARM_TOKEN" \
        -H 'content-type: application/json' \
        --data "$body" || echo 000)

    if [[ "$http" =~ ^2 ]]; then
        ok "$label : granted"
    else
        local msg; msg=$(cat "$tmp" 2>/dev/null || true)
        if echo "$msg" | grep -q 'RoleAssignmentExists'; then
            info "$label : already exists (skip)"
        else
            err "$label : HTTP $http $msg"
            HAD_FAILURE=1
        fi
    fi
    rm -f "$tmp"
}

ACR_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/foundry-workshop/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME"
ACCOUNT_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/foundry-workshop/providers/Microsoft.CognitiveServices/accounts/$ACCOUNT_NAME"
PROJECT_SCOPE="$ACCOUNT_SCOPE/projects/$PROJECT_NAME"

grant_role "$ACR_SCOPE"     "$INSTANCE_PID"  "$ACR_PULL_ROLE_ID"      "AcrPull        on ACR     -> instance"
grant_role "$ACR_SCOPE"     "$BLUEPRINT_PID" "$ACR_PULL_ROLE_ID"      "AcrPull        on ACR     -> blueprint"
grant_role "$ACCOUNT_SCOPE" "$INSTANCE_PID"  "$AZURE_AI_USER_ROLE_ID" "Azure AI User  on account -> instance"
grant_role "$PROJECT_SCOPE" "$INSTANCE_PID"  "$AZURE_AI_USER_ROLE_ID" "Azure AI User  on project -> instance"

if [[ "$HAD_FAILURE" -ne 0 ]]; then
    err "One or more grants failed — see errors above."
    exit 2
fi
ok "All runtime roles granted. Agent runtime should now be reachable."
