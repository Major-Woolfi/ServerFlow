set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_ROOT}/scripts/common/logger.sh"
source "${PROJECT_ROOT}/scripts/common/validate.sh"
source "${PROJECT_ROOT}/scripts/common/ssh.sh"

function update_single_server() {
    local server_name="${1:-}"
    local config_file="${PROJECT_ROOT}/config/servers.json"

    if [[ -z "$server_name" ]]; then
        log_error "Server name required"
        exit 1
    fi

    local server_info
    server_info=$(python3 -c "
import json
with open('${config_file}') as f:
    config = json.load(f)
if '${server_name}' not in config:
    print('NOT_FOUND')
    exit(0)
s = config['${server_name}']
print(f\"{s.get('host','')}|{s.get('ssh_user','root')}|{s.get('type','node')}\")
")

    if [[ "$server_info" == "NOT_FOUND" ]]; then
        log_error "Server '${server_name}' not found"
        exit 1
    fi

    IFS='|' read -r shost suser stype <<< "$server_info"

    log_init "$server_name"
    log_info "Updating ${stype} server: ${server_name} (${shost})"

    ssh_init --host "$shost" --user "$suser" --name "$server_name"
    if ! ssh_test; then
        log_error "Cannot connect to ${server_name}"
        exit 1
    fi

    ssh_run "apt update && apt upgrade -y"
    log_success "OS packages updated on ${server_name}"

    if ssh_run "command -v x-ui" &>/dev/null; then
        ssh_run "x-ui update" 2>/dev/null && log_success "3X-UI updated" || log_warn "3X-UI update failed"
    fi

    if ssh_run "command -v bt" &>/dev/null; then
        ssh_run "bash <(curl -Ls https://raw.githubusercontent.com/aapanel/btpanel/master/scripts/update-panel.sh)" 2>/dev/null && log_success "aaPanel updated" || log_warn "aaPanel update failed"
    fi

    log_success "Update complete for ${server_name}"
}

function update_all_servers() {
    local config_file="${PROJECT_ROOT}/config/servers.json"
    if [[ ! -f "$config_file" ]]; then
        log_error "Config not found: $config_file"
        exit 1
    fi

    log_init "all-servers"
    log_info "Updating ALL servers"

    local names
    names=$(python3 -c "
import json
with open('${config_file}') as f:
    config = json.load(f)
for name in config:
    print(name)
")

    local success=0
    local failed=0

    for sname in $names; do
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