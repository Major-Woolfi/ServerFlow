set -euo pipefail

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"

function update_node() {
    local sname="${1:-}"
    local shost="${2:-}"
    local suser="${3:-root}"
    local spass="${4:-}"
    local skey="${5:-}"

    if [[ -z "$sname" || -z "$shost" ]]; then
        echo "Usage: update_node.sh <name> <host> [user] [password] [key]" >&2
        exit 1
    fi

    log_init "$sname"
    log_info "=== Updating NODE: ${sname} (${shost}) ==="

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

    log_info "Updating Nginx..."
    ssh_run "apt install --only-upgrade nginx -y 2>/dev/null || yum update nginx -y 2>/dev/null || log_warn 'Nginx update skipped'"

    log_success "=== Update complete for node ${sname} ==="
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    update_node "$@"
fi
