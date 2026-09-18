set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_ROOT}/scripts/common/logger.sh"
source "${PROJECT_ROOT}/scripts/common/validate.sh"
source "${PROJECT_ROOT}/scripts/common/ssh.sh"
source "${PROJECT_ROOT}/scripts/main/update_main.sh"

function update_main() {
    local sname="${1:-}"
    local shost="${2:-}"
    local suser="${3:-root}"
    local spass="${4:-}"
    local skey="${5:-}"

    if [[ -z "$sname" || -z "$shost" ]]; then
        echo "Usage: update_main.sh <name> <host> [user] [password] [key]" >&2
        exit 1
    fi

    log_init "$sname"
    log_info "=== Updating MAIN server: ${sname} (${shost}) ==="

    ssh_init --host "$shost" --user "$suser" --pass "$spass" --key "$skey" --name "$sname"
    if ! ssh_test; then
        log_error "Cannot connect to ${sname}"
        exit 1
    fi

    log_info "Updating OS packages..."
    ssh_run "apt update && apt upgrade -y"
    log_success "OS packages updated"

    log_info "Updating 3X-UI..."
    ssh_run "x-ui update" 2>/dev/null && log_success "3X-UI updated" || log_warn "3X-UI update failed"

    log_info "Updating X-Ray core..."
    ssh_run "x-ui xray-update" 2>/dev/null && log_success "X-Ray updated" || log_warn "X-Ray update failed"

    log_info "Updating Nginx (aaPanel)..."
    ssh_run "apt install --only-upgrade nginx -y 2>/dev/null || yum update nginx -y 2>/dev/null || log_warn 'Nginx update skipped'"

    log_info "Updating PHP..."
    ssh_run "apt install --only-upgrade php* -y 2>/dev/null || yum update php* -y 2>/dev/null || log_warn 'PHP update skipped'"

    log_info "Updating MySQL/MariaDB..."
    ssh_run "apt install --only-upgrade mysql-server mariadb-server -y 2>/dev/null || yum update mysql-server mariadb-server -y 2>/dev/null || log_warn 'DB update skipped'"

    log_info "Updating aaPanel..."
    ssh_run "bash <(curl -Ls https://raw.githubusercontent.com/aapanel/btpanel/master/scripts/update-panel.sh)" 2>/dev/null && log_success "aaPanel updated" || log_warn "aaPanel update failed"

    log_success "=== Update complete for main ${sname} ==="
}

update_main "$@"