set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source scripts/common/logger.sh
source scripts/common/validate.sh
source scripts/common/ssh.sh
source scripts/common/setup_node.sh
source scripts/common/setup_main.sh
source scripts/common/update_node.sh
source scripts/migrate/full_migrate.sh
source scripts/admin/add_server.sh
source scripts/admin/update_all.sh

function update_single_server() {
    local server_name="${1:-}"
    local config_file="${SCRIPT_DIR}/config/servers.json"

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

function show_menu() {
    echo ""
    echo "=== ServerFlow ==="
    echo "1) Configure new node (3X-UI)"
    echo "2) Configure main server (3X-UI + aaPanel)"
    echo "3) Migrate main server"
    echo "4) Add server to database"
    echo "5) Update all servers"
    echo "6) Update single server"
    echo "7) Exit"
    echo ""
}

function main() {
    while true; do
        show_menu
        read -rp "Select option: " choice
        case "$choice" in
            1)
                read -rp "Server name: " sname
                read -rp "Server host (IP/domain): " shost
                read -rp "SSH user [root]: " suser
                suser="${suser:-root}"
                setup_node "$sname" "$shost" "$suser"
                ;;
            2)
                read -rp "Server name: " sname
                read -rp "Server host (IP/domain): " shost
                read -rp "SSH user [root]: " suser
                suser="${suser:-root}"
                setup_main_interactive "$sname" "$shost" "$suser"
                ;;
            3)
                read -rp "Old main server name: " old_name
                read -rp "New main server name: " new_name
                read -rp "New main host (IP/domain): " new_host
                full_migrate "$old_name" "" "$new_name" "$new_host"
                ;;
            4)
                add_server_interactive
                ;;
            5)
                update_all_servers
                ;;
            6)
                read -rp "Server name: " sname
                update_single_server "$sname"
                ;;
            7)
                echo "Goodbye"
                exit 0
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
    done
}

main "$@"