set -euo pipefail

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"

function update_single_server() {
    local server_name="${1:-}"

    if [[ -z "$server_name" ]]; then
        log_error "Server name required"
        exit 1
    fi

    if ! server_exists "$server_name"; then
        log_error "Server '${server_name}' not found"
        exit 1
    fi

    local shost suser stype
    local config_data
    config_data=$(load_server_config "$server_name")

    shost=$(echo "$config_data" | grep '^host=' | cut -d= -f2-)
    suser=$(echo "$config_data" | grep '^ssh_user=' | cut -d= -f2-)
    stype=$(echo "$config_data" | grep '^type=' | cut -d= -f2-)

    shost="${shost:-}"
    suser="${suser:-root}"
    stype="${stype:-node}"

    log_init "$server_name"
    log_info "Updating ${stype} server: ${server_name} (${shost})"

    local skey=""
    local spass=""
    local key_path=$(echo "$config_data" | grep '^ssh_key_path=' | cut -d= -f2-)
    if [[ -n "$key_path" ]]; then
        skey="${PROJECT_ROOT}/${key_path}"
        [[ ! -f "$skey" ]] && skey=""
    fi
    spass=$(echo "$config_data" | grep '^ssh_password=' | cut -d= -f2-)

    ssh_init --host "$shost" --user "$suser" --pass "$spass" --key "$skey" --name "$server_name"
    if ! ssh_test; then
        log_error "Cannot connect to ${server_name}"
        exit 1
    fi

    log_info "Updating OS packages..."
    ssh_run "apt update && apt upgrade -y"
    log_success "OS packages updated"

    local panel_type
    panel_type=$(ssh_detect_panel_version "3x-ui")
    if [[ "$panel_type" != "unknown" ]]; then
        log_info "3X-UI detected (v${panel_type}), updating..."
        ssh_run "x-ui update" 2>/dev/null && log_success "3X-UI updated" || log_warn "3X-UI update failed"
        ssh_run "x-ui xray-update" 2>/dev/null && log_success "X-Ray updated" || log_warn "X-Ray update failed"
    fi

    if ssh_run "command -v bt" &>/dev/null; then
        local bp_ver
        bp_ver=$(ssh_detect_panel_version "aapanel")
        log_info "aaPanel detected (v${bp_ver}), updating..."
        ssh_run "bash <(curl -Ls https://raw.githubusercontent.com/aapanel/btpanel/master/scripts/update-panel.sh)" 2>/dev/null && log_success "aaPanel updated" || log_warn "aaPanel update failed"
    fi

    log_success "Update complete for ${server_name}"
}

function update_all_servers() {
    if [[ ! -d "${PROJECT_ROOT}/data/servers" ]]; then
        log_error "No servers configured"
        exit 1
    fi

    log_init "all-servers"
    log_info "Updating ALL servers"

    local success=0
    local failed=0

    for sname in $(list_servers); do
        if update_single_server "$sname"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
            log_error "Failed to update: $sname"
        fi
    done

    log_info "Update summary: ${success} succeeded, ${failed} failed"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --all|-a)
            update_all_servers
            ;;
        *)
            update_single_server "$1"
            ;;
    esac
fi