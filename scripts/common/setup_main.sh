set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_ROOT}/scripts/common/logger.sh"
source "${PROJECT_ROOT}/scripts/common/validate.sh"
source "${PROJECT_ROOT}/scripts/common/ssh.sh"
source "${PROJECT_ROOT}/scripts/common/install.sh"
source "${PROJECT_ROOT}/scripts/common/config_3xui.sh"
source "${PROJECT_ROOT}/scripts/common/config_aapanel.sh"

STANDALONE=0
if [[ -d /etc/x-ui/ ]]; then
    STANDALONE=1
    PROJECT_ROOT="$(pwd)"
    log_info "Standalone mode: running on target server"
fi

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

    if [[ $STANDALONE -eq 1 ]]; then
        log_init "$sname"
        log_info "=== Configuring MAIN (standalone): ${sname} ==="

        install_3xui_remote "$shost" "$suser" "$spass" "$skey" || { log_error "3X-UI install failed"; exit 1; }
        config_3xui_remote "$shost" "$suser" "$spass" "$skey"

        install_aapanel_remote "$shost" "$suser" "$spass" "$skey" || { log_error "aaPanel install failed"; exit 1; }
        config_aapanel_remote "$shost" "$suser" "$spass" "$skey"

        save_secrets_3xui "$sname" "$shost" "$suser" "$spass" "$skey"

        log_success "=== Main server ${sname} configured ==="
        return 0
    fi

    log_init "$sname"
    log_info "=== Configuring MAIN server: ${sname} (${shost}) ==="

    install_3xui_remote "$shost" "$suser" "$spass" "$skey"
    config_3xui_remote "$shost" "$suser" "$spass" "$skey"

    install_aapanel_remote "$shost" "$suser" "$spass" "$skey"
    config_aapanel_remote "$shost" "$suser" "$spass" "$skey"

    save_secrets_3xui "$sname" "$shost" "$suser" "$spass" "$skey"

    log_success "=== Main server ${sname} configured ==="
}

setup_main_interactive "$@"