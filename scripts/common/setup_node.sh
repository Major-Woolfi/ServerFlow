set -euo pipefail

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"
source "${PROJECT_ROOT}/scripts/common/setup_common.sh"

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

    log_init "$sname"

    if [[ $STANDALONE -eq 1 ]]; then
        log_info "=== Setting up NODE (standalone): ${sname} ==="

        install_3xui_remote "$shost" "$suser" "$spass" "$skey" || { log_error "3X-UI install failed"; exit 1; }
        config_3xui_remote "$shost" "$suser" "$spass" "$skey"

        local has_aapanel="n"
        read -rp "Install aaPanel on this node? (y/n): " has_aapanel
        if [[ "$has_aapanel" =~ ^[Yy] ]]; then
            install_aapanel_remote "$shost" "$suser" "$spass" "$skey"
            config_aapanel_remote "$shost" "$suser" "$spass" "$skey"
        fi

        setup_server_save_secrets "$sname" "$shost" "$suser" "$spass" "$skey"

        log_success "=== Node ${sname} setup complete ==="
        return 0
    fi

    log_info "=== Setting up NODE: ${sname} (${shost}) ==="

    setup_server_checks "$shost" || exit 1

    setup_server_install "$shost" "$suser" "$spass" "$skey" || exit 1

    local has_aapanel="n"
    read -rp "Install aaPanel on this node? (y/n): " has_aapanel
    if [[ "$has_aapanel" =~ ^[Yy] ]]; then
        install_aapanel_remote "$shost" "$suser" "$spass" "$skey"
        config_aapanel_remote "$shost" "$suser" "$spass" "$skey"
    fi

    setup_server_save_secrets "$sname" "$shost" "$suser" "$spass" "$skey"

    log_success "=== Node ${sname} setup complete ==="
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_node "$@"
fi
