#!/usr/bin/env bash
#
# fetch-traces.sh — bash port of fetch-traces.ps1
#
# 拉 Foundry "Agents → Monitor → Operational metrics" 数据, 写成 data/my-metrics.js
# 给本地 index.html (echarts) 渲染。用 SP OAuth2 client_credentials 拿 ARM token,
# 不依赖 az login / azd auth。
#
# 用法:
#   ./fetch-traces.sh                            # 默认 60min / PT5M
#   ./fetch-traces.sh --minutes 180
#   ./fetch-traces.sh --agent-name research-agent-stu05 --minutes 60

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_NAME=""
MINUTES=60
INTERVAL="PT5M"
OUTPUT_PATH="${SCRIPT_DIR}/data/my-metrics.js"
ENV_FILE=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]
  --agent-name NAME      Agent name (default: from AGENT_NAME / research-agent-\${STUDENT_SUFFIX})
  --minutes N            Time window in minutes (default: 60)
  --interval ISO8601     Aggregation interval (default: PT5M)
  --output-path PATH     Output .js path (default: ./data/my-metrics.js)
  --env-file PATH        .env file (default: ../.env relative to this script)
  -h, --help             Show this help

Examples:
  $(basename "$0") --minutes 60 --interval PT5M
  $(basename "$0") --agent-name research-agent-stu05 --minutes 180
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent-name)  AGENT_NAME="$2"; shift 2 ;;
        --minutes)     MINUTES="$2"; shift 2 ;;
        --interval)    INTERVAL="$2"; shift 2 ;;
        --output-path) OUTPUT_PATH="$2"; shift 2 ;;
        --env-file)    ENV_FILE="$2"; shift 2 ;;
        -h|--help)     usage; exit 0 ;;
        *)             echo "Unknown arg: $1" >&2; usage; exit 1 ;;
    esac
done

info() { printf '\033[36mℹ️  %s\033[0m\n' "$*"; }
warn() { printf '\033[33m⚠️  %s\033[0m\n' "$*"; }
err()  { printf '\033[31m❌ %s\033[0m\n' "$*" >&2; }
ok()   { printf '\033[32m✅ %s\033[0m\n' "$*"; }

command -v curl >/dev/null 2>&1 || { err "curl 未安装"; exit 1; }
command -v jq   >/dev/null 2>&1 || { err "jq 未安装 (macOS: brew install jq; Ubuntu/Debian: apt-get install jq)"; exit 1; }

# ---------------------------------------------------------------------------
# 1. Load .env, resolve config
# ---------------------------------------------------------------------------
[[ -z "$ENV_FILE" ]] && ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ -f "$ENV_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        [[ -z "$line" ]] && continue
        case "$line" in
            \#*) continue ;;
        esac
        if [[ "$line" == *=* ]]; then
            key="${line%%=*}"
            val="${line#*=}"
            key="$(printf '%s' "$key" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
            val="$(printf '%s' "$val" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
            case "$val" in
                \"*\") val="${val#\"}"; val="${val%\"}" ;;
                \'*\') val="${val#\'}"; val="${val%\'}" ;;
            esac
            if [[ -n "$val" && -z "${!key:-}" ]]; then
                export "$key=$val"
            fi
        fi
    done < "$ENV_FILE"
fi

PROJECT_ID="${AZURE_AI_PROJECT_ID:-}"
CLIENT_ID="${AZURE_CLIENT_ID:-}"
SECRET="${AZURE_CLIENT_SECRET:-}"
TENANT_ID="${AZURE_TENANT_ID:-}"

[[ -z "$PROJECT_ID" ]] && { err "AZURE_AI_PROJECT_ID 未设置 (.env)."; exit 1; }
if [[ -z "$CLIENT_ID" || -z "$SECRET" || -z "$TENANT_ID" ]]; then
    err "SP 凭据 (AZURE_CLIENT_ID/SECRET/TENANT_ID) 未在 .env 设置."; exit 1
fi

if [[ -z "$AGENT_NAME" ]]; then
    AGENT_NAME="${AGENT_NAME_OVERRIDE:-}"
fi
# After .env load, $AGENT_NAME may be set by export. Fall back to STUDENT_SUFFIX.
AGENT_NAME="${AGENT_NAME:-${AGENT_NAME_FROM_ENV:-}}"
if [[ -z "$AGENT_NAME" ]]; then
    suffix="${STUDENT_SUFFIX:-}"
    if [[ -n "$suffix" ]]; then
        AGENT_NAME="research-agent-${suffix}"
    else
        AGENT_NAME="research-agent"
    fi
fi
info "agent=$AGENT_NAME  window=${MINUTES}min  interval=$INTERVAL"

# ---------------------------------------------------------------------------
# 2. ARM SP token (OAuth2 client_credentials)
# ---------------------------------------------------------------------------
arm_token=$(
    curl -sS --max-time 30 \
        -X POST "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "client_id=${CLIENT_ID}" \
        --data-urlencode "client_secret=${SECRET}" \
        --data-urlencode "scope=https://management.azure.com/.default" \
        --data-urlencode "grant_type=client_credentials" \
    | jq -r '.access_token // empty'
) || { err "OAuth2 token 请求失败 (curl/jq)"; exit 2; }

if [[ -z "$arm_token" ]]; then
    err "OAuth2 token 失败: 未拿到 access_token (检查 SP 凭据)"; exit 2
fi

# ---------------------------------------------------------------------------
# 3. Query Azure Monitor metrics
# ---------------------------------------------------------------------------
# Time window — BSD date (macOS) vs GNU date (Linux)
if start_iso=$(date -u -v-"${MINUTES}"M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null); then
    :
else
    start_iso=$(date -u -d "-${MINUTES} minutes" +"%Y-%m-%dT%H:%M:%SZ")
fi
end_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESPAN="${start_iso}/${end_iso}"

urlencode() { jq -rn --arg s "$1" '$s | @uri'; }

get_metric() {
    local scope="$1" names="$2" agg="$3" filter="${4:-}"
    local url="https://management.azure.com${scope}/providers/microsoft.insights/metrics?api-version=2018-01-01&metricnames=$(urlencode "$names")&timespan=${TIMESPAN}&interval=${INTERVAL}&aggregation=${agg}"
    if [[ -n "$filter" ]]; then
        url="${url}&\$filter=$(urlencode "$filter")"
    fi
    local resp
    resp=$(curl -sS --max-time 30 -H "Authorization: Bearer ${arm_token}" "$url" || echo '')
    if [[ -n "$resp" ]] && echo "$resp" | jq -e '.value' >/dev/null 2>&1; then
        printf '%s' "$resp"
    else
        local msg
        msg=$(printf '%s' "$resp" | jq -r '.error.message // "empty / invalid response"' 2>/dev/null || echo "request failed")
        warn "metric query failed (${names}): ${msg}"
        printf '%s' '{"value":[]}'
    fi
}

# Account scope = project scope minus trailing /projects/<name>
account_id="${PROJECT_ID%/projects/*}"

# 3a. AgentResponses split by AgentId (cross-student comparison)
resp_by_agent=$(get_metric "$PROJECT_ID" "AgentResponses" "Total" "AgentId eq '*'")

# 3b. Project-wide tokens & tool calls
tokens_metrics=$(get_metric "$PROJECT_ID" "AgentInputTokens,AgentOutputTokens,AgentToolCalls,AgentEvents,AgentMessages" "Total")

# 3c. Model deployment metrics live on account scope
model_total=$(get_metric "$account_id" "ModelRequests" "Total" "ModelDeploymentName eq '*'")
model_avg=$(get_metric   "$account_id" "TimeToResponse,TokensPerSecond" "Average" "ModelDeploymentName eq '*'")

# ---------------------------------------------------------------------------
# 4. Reshape with jq and write JS module
# ---------------------------------------------------------------------------
generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

result=$(jq -n \
    --arg agent_name "$AGENT_NAME" \
    --arg generated_at "$generated_at" \
    --argjson minutes "$MINUTES" \
    --arg interval "$INTERVAL" \
    --argjson resp "$resp_by_agent" \
    --argjson tokens "$tokens_metrics" \
    --argjson model_total "$model_total" \
    --argjson model_avg "$model_avg" \
'
def find_metric(obj; n): (obj.value // []) | map(select(.name.value == n)) | first;
def agent_id_of(ts): ((ts.metadatavalues // []) | map(select(.name.value == "agentid")) | first | .value);
def sum_total(ts): ((ts.data // []) | map(.total // 0) | add // 0);
def series_total(ts):
    { timestamps: ((ts.data // []) | map(.timeStamp))
    , values:     ((ts.data // []) | map(.total // 0)) };
def series_avg(ts):
    { timestamps: ((ts.data // []) | map(.timeStamp))
    , values:     ((ts.data // []) | map(.average // 0)) };

(find_metric($resp; "AgentResponses"))                     as $agent_metric |
(($agent_metric // {}).timeseries // [])                   as $all_ts |
($all_ts
   | map({ agentId: agent_id_of(.), total: sum_total(.) })
   | sort_by(-.total))                                     as $agents_share |
($all_ts
   | map(select(
        (agent_id_of(.)) as $aid
        | ($aid == $agent_name)
       or (($aid // "") | startswith($agent_name + ":"))))
   | first)                                                as $my_ts |
(sum_total($my_ts // {}))                                  as $my_total |
($agents_share | map(.total) | add // 0)                   as $all_total |

(((find_metric($tokens; "AgentInputTokens")  // {}).timeseries // [])[0] // {}) as $in_ts |
(((find_metric($tokens; "AgentOutputTokens") // {}).timeseries // [])[0] // {}) as $out_ts |
(((find_metric($tokens; "AgentToolCalls")    // {}).timeseries // [])[0] // {}) as $tool_ts |

(((find_metric($model_total; "ModelRequests")  // {}).timeseries // [])[0] // {}) as $req_ts |
(((find_metric($model_avg;   "TimeToResponse") // {}).timeseries // [])[0] // {}) as $lat_ts |
(((find_metric($model_avg;   "TokensPerSecond")// {}).timeseries // [])[0] // {}) as $tps_ts |

(series_total($in_ts))                                     as $in_series |
(series_total($out_ts))                                    as $out_series |
(series_total($tool_ts))                                   as $tool_series |
(($in_series.values   | add) // 0)                         as $in_tot |
(($out_series.values  | add) // 0)                         as $out_tot |
(($tool_series.values | add) // 0)                         as $tool_tot |

{ agent_name: $agent_name
, generated_at: $generated_at
, time_window_minutes: $minutes
, interval: $interval
, kpi:
    { my_total_responses:    ($my_total | floor)
    , project_input_tokens:  ($in_tot   | floor)
    , project_output_tokens: ($out_tot  | floor)
    , project_total_tokens:  (($in_tot + $out_tot) | floor)
    , project_tool_calls:    ($tool_tot | floor)
    , my_share_pct:
        (if $all_total > 0
         then (($my_total / $all_total) * 1000 | round) / 10
         else 0
         end)
    }
, series:
    { my_responses:       series_total($my_ts // {})
    , project_in_tokens:  $in_series
    , project_out_tokens: $out_series
    , project_tool_calls: $tool_series
    , model_requests:     series_total($req_ts)
    , model_latency_ms:   series_avg($lat_ts)
    , tokens_per_second:  series_avg($tps_ts)
    }
, agents_share: $agents_share
}
')

mkdir -p "$(dirname "$OUTPUT_PATH")"
printf 'window.__METRICS__ = %s;\n' "$result" > "$OUTPUT_PATH"

echo ""
ok "写出 $OUTPUT_PATH"
my_resp=$(printf '%s' "$result"  | jq -r '.kpi.my_total_responses')
my_share=$(printf '%s' "$result" | jq -r '.kpi.my_share_pct')
in_tok=$(printf '%s' "$result"   | jq -r '.kpi.project_input_tokens')
out_tok=$(printf '%s' "$result"  | jq -r '.kpi.project_output_tokens')
printf '\033[2m   my_responses=%s  my_share=%s%%  project_in_tokens=%s  project_out_tokens=%s\033[0m\n' \
    "$my_resp" "$my_share" "$in_tok" "$out_tok"
echo ""
printf '\033[33m用浏览器打开 ./index.html 即可查看。\033[0m\n'
