set -euo pipefail

function validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local o1 o2 o3 o4
        IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
        if (( o1 <= 255 && o2 <= 255 && o3 <= 255 && o4 <= 255 )); then
            return 0
        fi
    fi
    return 1
}

function validate_hostname() {
    local host="$1"
    if [[ "$host" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\.?$ ]]; then
        return 0
    fi
    return 1
}

function validate_server_name() {
    local name="$1"
    if [[ "$name" =~ ^[a-zA-Z0-9_\-]+$ ]]; then
        return 0
    fi
    return 1
}

function check_local_deps() {
    local missing=()
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "[validate] Missing local dependencies: ${missing[*]}" >&2
        return 1
    fi
    return 0
}

function check_remote_deps() {
    local host="$1"
    local user="$2"
    local pass="$3"
    local key="$4"
    shift 4
    local deps=("$@")

    ssh_init --host "$host" --user "$user" --pass "$pass" --key "$key" --name "$host"

    local missing=()
    for dep in "${deps[@]}"; do
        if ! ssh_run "command -v ${dep}" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "[validate] Missing remote dependencies on ${host}: ${missing[*]}" >&2
        return 1
    fi
    return 0
}

function check_host_reachable() {
    local host="$1"
    local port="${2:-22}"
    if command -v timeout &>/dev/null; then
        timeout 5 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null
    elif command -v nc &>/dev/null; then
        nc -z -w5 "$host" "$port" 2>/dev/null
    else
        ping -n 1 -w 5 "$host" &>/dev/null
    fi
}