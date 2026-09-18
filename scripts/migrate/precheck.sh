set -euo pipefail

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"

function precheck() {
    local old_host="$1"
    local new_host="$2"
    local old_user="${3:-root}"
    local new_user="${4:-root}"

    log_init "migrate"
    log_info "=== Pre-check migration ==="
    log_info "Old server: ${old_user}@${old_host}"
    log_info "New server: ${new_user}@${new_host}"

    local errors=0

    for info in "${old_user}@${old_host}|old" "${new_user}@${new_host}|new"; do
        IFS='|' read -r host label <<< "$info"
        local h u
        h="${host%%@*}"
        u="${host##*@}"

        if ! validate_ip "$h" && ! validate_hostname "$h"; then
            log_error "[${label}] Invalid host: $h"
            errors=$((errors + 1))
        fi

        if ! check_host_reachable "$h" 22; then
            log_error "[${label}] Host not reachable: $h"
            errors=$((errors + 1))
        else
            log_success "[${label}] Host reachable: $h"
        fi
    done

    log_info "Checking disk space on new server..."
    ssh_init --host "$new_host" --user "$new_user" --name "$new_host"
    local disk_info
    disk_info=$(ssh_run "df -h / | tail -1 | awk '{print \$4}'" 2>/dev/null || echo "unknown")
    log_info "Available disk space on new server: ${disk_info}"

    log_info "Checking rsync availability..."
    if check_local_deps rsync; then
        log_success "rsync available locally"
    else
        log_error "rsync not available locally"
        errors=$((errors + 1))
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Pre-check failed with ${errors} error(s)"
        return 1
    fi

    log_success "Pre-check passed"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    precheck "$@"
fi
