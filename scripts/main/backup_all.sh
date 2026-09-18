set -euo pipefail

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"
source "${PROJECT_ROOT}/scripts/common/validate.sh"

function backup_all() {
    local sname="${1:-}"
    local shost="${2:-}"
    local suser="${3:-root}"
    local spass="${4:-}"
    local skey="${5:-}"

    if [[ -z "$sname" || -z "$shost" ]]; then
        echo "Usage: backup_all.sh <name> <host> [user] [password] [key]" >&2
        exit 1
    fi

    log_init "$sname"
    log_info "=== Backing up MAIN: ${sname} (${shost}) ==="

    ssh_init --host "$shost" --user "$suser" --pass "$spass" --key "$skey" --name "$sname"
    if ! ssh_test; then
        log_error "Cannot connect to ${sname}"
        exit 1
    fi

    log_info "Creating backup on remote server..."
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local remote_backup="/tmp/sf_backup_${timestamp}.tar.gz"

    ssh_run "tar czf ${remote_backup} \
        /etc/x-ui/ \
        /www/server/ \
        /www/website/ \
        /www/rewrite/ \
        /www/panel/ \
        /var/lib/mysql/ \
        /var/lib/redis/ \
        /root/.ssh/ 2>/dev/null || true"

    ssh_run "echo ${remote_backup}"
    log_success "Backup created: ${remote_backup}"
    log_info "Download manually: scp ${suser}@${shost}:${remote_backup} ./"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    backup_all "$@"
fi