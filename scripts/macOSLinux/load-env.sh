#!/usr/bin/env bash
#
# load-env.sh
# -------------
# 把 workshop 根的 .env 加载到当前 shell 的环境变量里。
#
# 用法 (在任意 Lab 子目录里):
#   source ../scripts/macOSLinux/load-env.sh                 # 默认读 workshop 根 .env
#   source ../scripts/macOSLinux/load-env.sh /path/to/.env   # 显式路径
#
# 其它 *.sh 脚本被调时会自己尝试 load 一次, 学员一般不用手动跑。
#
# 注意: 用 `source` (或 `.`) 运行才能把变量真正注入当前 shell。
# 如果直接 `./load-env.sh` 跑, 变量只活在子进程里, 当前 shell 看不到。

# ---- locate this file even when sourced ----
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _load_env_self="${BASH_SOURCE[0]}"
else
    _load_env_self="$0"
fi
_load_env_dir="$(cd "$(dirname "$_load_env_self")" && pwd)"

ENV_PATH="${1:-$_load_env_dir/../../.env}"

if [[ ! -f "$ENV_PATH" ]]; then
    printf '\033[33m⚠️  .env not found at %s. Copy .env.example to .env and fill in.\033[0m\n' "$ENV_PATH"
    unset _load_env_self _load_env_dir
    return 0 2>/dev/null || exit 0
fi

_load_env_count=0
while IFS= read -r _line || [[ -n "$_line" ]]; do
    # strip leading/trailing whitespace
    _line="${_line#"${_line%%[![:space:]]*}"}"
    _line="${_line%"${_line##*[![:space:]]}"}"
    [[ -z "$_line" || "${_line:0:1}" == "#" ]] && continue

    _eq="${_line%%=*}"
    [[ "$_eq" == "$_line" ]] && continue   # no '=' on the line

    _k="$_eq"
    _v="${_line#*=}"

    # trim k
    _k="${_k#"${_k%%[![:space:]]*}"}"
    _k="${_k%"${_k##*[![:space:]]}"}"
    # trim v + surrounding quotes
    _v="${_v#"${_v%%[![:space:]]*}"}"
    _v="${_v%"${_v##*[![:space:]]}"}"
    if [[ "${_v:0:1}" == '"' && "${_v: -1}" == '"' ]]; then _v="${_v:1:${#_v}-2}"; fi
    if [[ "${_v:0:1}" == "'" && "${_v: -1}" == "'" ]]; then _v="${_v:1:${#_v}-2}"; fi

    # expand ${VAR} against already-loaded env (single pass loop)
    while [[ "$_v" =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\} ]]; do
        _name="${BASH_REMATCH[1]}"
        _val="${!_name-}"
        [[ -z "$_val" ]] && break
        _v="${_v//\$\{$_name\}/$_val}"
    done

    # valid identifier?
    if [[ "$_k" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        export "$_k=$_v"
        _load_env_count=$((_load_env_count + 1))
    fi
done < "$ENV_PATH"

printf '\033[32m✅ loaded %s vars from %s\033[0m\n' "$_load_env_count" "$ENV_PATH"

unset _load_env_self _load_env_dir _load_env_count _line _eq _k _v _name _val
