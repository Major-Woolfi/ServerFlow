set -euo pipefail

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"

function setup_server_checks() {
    local host="$1"
    if ! validate_ip "$host" && ! validate_hostname "$host"; then
        log_error "Invalid host: $host"
        return 1
    fi
    if ! check_host_reachable "$host" 22; then
        log_error "Host not reachable: $host"
        return 1
    fi
    return 0
}

function setup_server_install() {
    local host="$1"
    local user="$2"
    local pass="${3:-}"
    local key="${4:-}"
    if ! install_3xui_remote "$host" "$user" "$pass" "$key"; then
        log_error "3X-UI install failed, aborting"
        return 1
    fi
    config_3xui_remote "$host" "$user" "$pass" "$key"
}

function setup_server_save_secrets() {
    local name="$1"
    local host="$2"
    local user="$3"
    local pass="${4:-}"
    local key="${5:-}"
    save_secrets_3xui "$name" "$host" "$user" "$pass" "$key"
}
