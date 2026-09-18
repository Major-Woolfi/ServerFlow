set -euo pipefail

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"
source "${PROJECT_ROOT}/scripts/common/validate.sh"
source "${PROJECT_ROOT}/scripts/common/ssh.sh"
source "${PROJECT_ROOT}/scripts/migrate/precheck.sh"
source "${PROJECT_ROOT}/scripts/migrate/sync_data.sh"
source "${PROJECT_ROOT}/scripts/migrate/update_certs.sh"

function full_migrate() {
    local old_name="${1:-}"
    local old_host="${2:-}"
    local new_name="${3:-}"
    local new_host="${4:-}"
    local user="${5:-root}"

    if [[ -z "$old_name" || -z "$old_host" || -z "$new_name" || -z "$new_host" ]]; then
        echo "Usage: full_migrate.sh <old_name> <old_host> <new_name> <new_host> [user]" >&2
        exit 1
    fi

    log_init "migrate-${old_name}-${new_name}"
    log_info "=== FULL MIGRATION ==="
    log_info "From: ${old_name} (${old_host})"
    log_info "To:   ${new_name} (${new_host})"

    precheck "$old_host" "$new_host" "$user" "$user" || {
        log_error "Pre-check failed. Aborting migration."
        exit 1
    }

    local transfer_mode=""
    while [[ "$transfer_mode" != "native" && "$transfer_mode" != "bridge" ]]; do
        echo "Transfer mode:"
        echo "  1) Native (direct rsync, requires both servers reachable)"
        echo "  2) Bridge (via this machine)"
        read -rp "Choose [1]: " mode_choice
        case "${mode_choice:-1}" in
            1) transfer_mode="native" ;;
            2) transfer_mode="bridge" ;;
            *) transfer_mode="native" ;;
        esac
    done

    sync_data "$old_host" "$new_host" "$user" "$user" "$transfer_mode" || {
        log_error "Data sync failed. Aborting."
        exit 1
    }

    update_certs "$new_host" "$user"

    echo ""
    echo "=== Migration data transfer complete ==="
    read -rp "Verify new server is working correctly. Continue to DNS update? (y/n): " verify

    if [[ "$verify" =~ ^[Yy] ]]; then
        read -rp "Run DNS update? (y/n): " do_dns
        if [[ "$do_dns" =~ ^[Yy] ]]; then
            local old_ip new_ip
            old_ip=$(dig +short "$old_host" 2>/dev/null | head -1 || echo "")
            new_ip=$(dig +short "$new_host" 2>/dev/null | head -1 || echo "")

            if [[ -n "$old_ip" && -n "$new_ip" ]]; then
                python3 "${project_win}/scripts/dns/update_records.py" "$old_ip" "$new_ip"
            else
                log_warn "Could not resolve IPs. Run DNS update manually."
            fi
        fi
    fi

    log_success "=== Migration of ${old_name} to ${new_name} complete ==="
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    full_migrate "$@"
fi