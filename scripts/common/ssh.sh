set -euo pipefail

SSH_EXEC=""
SSH_NAME=""
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -o ServerAliveInterval=60"

function ssh_init() {
    local host=""
    local user=""
    local pass=""
    local key=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host)   host="$2"; shift 2 ;;
            --user)   user="$2"; shift 2 ;;
            --pass)   pass="$2"; shift 2 ;;
            --key)    key="$2"; shift 2 ;;
            --name)   SSH_NAME="$2"; shift 2 ;;
            *)        echo "[ssh] Unknown arg: $1" >&2; exit 1 ;;
        esac
    done

    if [[ -z "$host" ]]; then
        echo "[ssh] ERROR: --host is required" >&2
        return 1
    fi
    if [[ -z "$user" ]]; then
        user="${SSH_USER:-root}"
    fi

    if [[ -z "$key" && -n "${SSH_NAME:-}" ]]; then
        local default_key="${PROJECT_ROOT:-$(pwd)}/ssh/${SSH_NAME}.key"
        if [[ -f "$default_key" ]]; then
            key="$default_key"
            log_info "Auto-detected SSH key: ${key}"
        fi
    fi

    if [[ -n "$key" ]]; then
        SSH_EXEC="ssh ${SSH_OPTS} -i '${key}' ${user}@${host}"
    elif [[ -n "$pass" ]]; then
        if ! command -v sshpass &>/dev/null; then
            echo "[ssh] ERROR: sshpass is required for password auth but not installed" >&2
            return 1
        fi
        SSH_EXEC="sshpass -p '${pass}' ssh ${SSH_OPTS} ${user}@${host}"
    else
        SSH_EXEC="ssh ${SSH_OPTS} ${user}@${host}"
    fi

    echo "[ssh] Ready: ${user}@${host}"
    return 0
}

function ssh_run() {
    local cmd="$1"
    if [[ -z "${SSH_EXEC:-}" ]]; then
        echo "[ssh] ERROR: ssh_init not called first" >&2
        return 1
    fi
    echo "[ssh] Executing on ${SSH_NAME:-unknown}: ${cmd}"
    eval "${SSH_EXEC}" "'${cmd}'"
}

function ssh_run_file() {
    local script="$1"
    if [[ -z "${SSH_EXEC:-}" ]]; then
        echo "[ssh] ERROR: ssh_init not called first" >&2
        return 1
    fi
    echo "[ssh] Sending ${script} to ${SSH_NAME:-unknown}"
    eval "${SSH_EXEC}" "'$(cat "${script}")'"
}

function ssh_test() {
    if [[ -z "${SSH_EXEC:-}" ]]; then
        echo "[ssh] ERROR: ssh_init not called first" >&2
        return 1
    fi
    eval "${SSH_EXEC}" "'echo SSH_OK'" 2>/dev/null
}

function ssh_detect_os() {
    if [[ -z "${SSH_EXEC:-}" ]]; then
        echo "unknown"
        return 1
    fi
    eval "${SSH_EXEC}" -- "uname -s" 2>/dev/null | tr -d '[:space:]'
}

function ssh_detect_panel_version() {
    local panel="$1"
    if [[ -z "${SSH_EXEC:-}" ]]; then
        echo "unknown"
        return 1
    fi
    case "$panel" in
        3x-ui)
            eval "${SSH_EXEC}" -- "x-ui version 2>/dev/null || x-ui getVersion 2>/dev/null || echo unknown" 2>/dev/null | tr -d '[:space:]'
            ;;
        aapanel)
            eval "${SSH_EXEC}" -- "python3 -c \"import json; f=open('/www/server/panel/data/info.json'); print(json.load(f).get('version','unknown'))\" 2>/dev/null || echo unknown" 2>/dev/null | tr -d '[:space:]'
            ;;
        *)
            echo "unknown"
            ;;
    esac
}