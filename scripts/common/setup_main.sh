set -euo pipefail

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"
source "${PROJECT_ROOT}/scripts/common/setup_common.sh"

function setup_main_interactive() {
    local sname="${1:-}"
    local shost="${2:-}"
    local suser="${3:-root}"
    local spass="${4:-}"
    local skey="${5:-}"

    if [[ -z "$sname" || -z "$shost" ]]; then
        echo "Usage: setup_main_interactive.sh <name> <host> [user] [password] [key]" >&2
        exit 1
    fi

    log_init "$sname"

    if [[ $STANDALONE -eq 1 ]]; then
        log_info "=== Configuring MAIN (standalone): ${sname} ==="

        install_3xui_remote "$shost" "$suser" "$spass" "$skey" || { log_error "3X-UI install failed"; exit 1; }
        config_3xui_remote "$shost" "$suser" "$spass" "$skey"

        install_aapanel_remote "$shost" "$suser" "$spass" "$skey" || { log_error "aaPanel install failed"; exit 1; }
        config_aapanel_remote "$shost" "$suser" "$spass" "$skey"

        setup_server_save_secrets "$sname" "$shost" "$suser" "$spass" "$skey"

        log_success "=== Main server ${sname} configured ==="
        return 0
    fi

    log_info "=== Configuring MAIN server: ${sname} (${shost}) ==="

    setup_server_checks "$shost" || exit 1

    setup_server_install "$shost" "$suser" "$spass" "$skey" || exit 1

    install_aapanel_remote "$shost" "$suser" "$spass" "$skey"
    config_aapanel_remote "$shost" "$suser" "$spass" "$skey"

    setup_server_save_secrets "$sname" "$shost" "$suser" "$spass" "$skey"

    log_success "=== Main server ${sname} configured ==="
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_main_interactive "$@"
fi
