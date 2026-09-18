set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_ROOT}/scripts/common/logger.sh"
source "${PROJECT_ROOT}/scripts/common/validate.sh"
source "${PROJECT_ROOT}/scripts/common/ssh.sh"
source "${PROJECT_ROOT}/scripts/common/install.sh"
source "${PROJECT_ROOT}/scripts/common/config_3xui.sh"
source "${PROJECT_ROOT}/scripts/common/config_aapanel.sh"

function setup_node() {
    local sname="${1:-}"
    local shost="${2:-}"
    local suser="${3:-root}"
    local spass="${4:-}"
    local skey="${5:-}"

    if [[ -z "$sname" || -z "$shost" ]]; then
        echo "Usage: setup_node.sh <name> <host> [user] [password] [key]" >&2
        exit 1
    fi

    if [[ $STANDALONE -eq 1 ]]; then
        log_init "$sname"
        log_info "=== Setting up NODE (standalone): ${sname} ==="

        install_3xui_remote "$shost" "$suser" "$spass" "$skey" || { log_error "3X-UI install failed"; exit 1; }
        config_3xui_remote "$shost" "$suser" "$spass" "$skey"

        local has_aapanel="n"
        read -rp "Install aaPanel on this node? (y/n): " has_aapanel
        if [[ "$has_aapanel" =~ ^[Yy] ]]; then
            install_aapanel_remote "$shost" "$suser" "$spass" "$skey"
            config_aapanel_remote "$shost" "$suser" "$spass" "$skey"
        fi

        save_secrets_3xui "$sname" "$shost" "$suser" "$spass" "$skey"

        log_success "=== Node ${sname} setup complete ==="
        return 0
    fi

    log_init "$sname"
    log_info "=== Setting up NODE: ${sname} (${shost}) ==="

    if ! validate_ip "$shost" && ! validate_hostname "$shost"; then
        log_error "Invalid host: $shost"
        exit 1
    fi

    if ! check_host_reachable "$shost" 22; then
        log_error "Host not reachable: $shost"
        exit 1
    fi

    install_3xui_remote "$shost" "$suser" "$spass" "$skey"
    if [[ $? -ne 0 ]]; then
        log_error "3X-UI install failed, aborting"
        exit 1
    fi

    config_3xui_remote "$shost" "$suser" "$spass" "$skey"

    local has_aapanel="n"
    read -rp "Install aaPanel on this node? (y/n): " has_aapanel
    if [[ "$has_aapanel" =~ ^[Yy] ]]; then
        install_aapanel_remote "$shost" "$suser" "$spass" "$skey"
        config_aapanel_remote "$shost" "$suser" "$spass" "$skey"
    fi

    save_secrets_3xui "$sname" "$shost" "$suser" "$spass" "$skey"

    log_success "=== Node ${sname} setup complete ==="
}

setup_node "$@"