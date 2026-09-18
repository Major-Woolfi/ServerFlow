set -euo pipefail

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"
source "${PROJECT_ROOT}/scripts/common/validate.sh"
source "${PROJECT_ROOT}/scripts/common/ssh.sh"

function restore_all() {
    local sname="${1:-}"
    local shost="${2:-}"
    local suser="${3:-root}"
    local spass="${4:-}"
    local skey="${5:-}"
    local backup_file="${6:-}"

    if [[ -z "$sname" || -z "$shost" || -z "$backup_file" ]]; then
        echo "Usage: restore_all.sh <name> <host> [user] [password] [key] <backup_file>" >&2
        exit 1
    fi

    log_init "$sname"
    log_info "=== Restoring MAIN: ${sname} (${shost}) ==="

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi

    ssh_init --host "$shost" --user "$suser" --pass "$spass" --key "$skey" --name "$sname"
    if ! ssh_test; then
        log_error "Cannot connect to ${sname}"
        exit 1
    fi

    local remote_path="/tmp/sf_restore_$(basename "$backup_file")"

    log_info "Uploading backup..."
    scp "$backup_file" "${suser}@${shost}:${remote_path}" 2>/dev/null || \
        ssh_run "cat > ${remote_path}" < "$backup_file"

    log_info "Restoring..."
    ssh_run "cd / && tar xzf ${remote_path}"

    ssh_run "rm -f ${remote_path}"
    log_success "Restore complete"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    restore_all "$@"
fi