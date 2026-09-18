set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"
source "${PROJECT_ROOT}/scripts/common/setup_node.sh"
source "${PROJECT_ROOT}/scripts/common/setup_main.sh"
source "${PROJECT_ROOT}/scripts/admin/add_server.sh"
source "${PROJECT_ROOT}/scripts/admin/update_all.sh"
source "${PROJECT_ROOT}/scripts/migrate/full_migrate.sh"
source "${PROJECT_ROOT}/scripts/main/update_main.sh"
source "${PROJECT_ROOT}/scripts/main/backup_all.sh"
source "${PROJECT_ROOT}/scripts/main/restore_all.sh"
source "${PROJECT_ROOT}/scripts/common/update_node.sh"

function show_menu() {
    echo ""
    echo "=== ServerFlow ==="
    echo "1) Configure new node (3X-UI)"
    echo "2) Configure main server (3X-UI + aaPanel)"
    echo "3) Migrate main server"
    echo "4) Add server to database"
    echo "5) Update all servers"
    echo "6) Update single server"
    echo "7) Update node"
    echo "8) Backup main server"
    echo "9) Restore main server"
    echo "10) Exit"
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
                read -rp "Server name: " sname
                read -rp "Server host (IP/domain): " shost
                read -rp "SSH user [root]: " suser
                suser="${suser:-root}"
                update_node "$sname" "$shost" "$suser"
                ;;
            8)
                read -rp "Server name: " sname
                read -rp "Server host: " shost
                read -rp "SSH user [root]: " suser
                suser="${suser:-root}"
                backup_all "$sname" "$shost" "$suser"
                ;;
            9)
                read -rp "Server name: " sname
                read -rp "Server host: " shost
                read -rp "SSH user [root]: " suser
                suser="${suser:-root}"
                read -rp "Backup file path: " backup_file
                restore_all "$sname" "$shost" "$suser" "" "$backup_file"
                ;;
            10)
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
