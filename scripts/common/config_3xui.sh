set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/common/logger.sh"
source "${PROJECT_ROOT}/scripts/common/validate.sh"
source "${PROJECT_ROOT}/scripts/common/ssh.sh"

STANDALONE=0
if [[ -d /etc/x-ui/ ]]; then
    STANDALONE=1
    PROJECT_ROOT="$(pwd)"
    log_info "Standalone mode: running on target server"
fi

function config_3xui_remote() {
    local host="$1"
    local user="$2"
    local pass="${3:-}"
    local key="${4:-}"

    if [[ $STANDALONE -eq 1 ]]; then
        ssh_init --host "localhost" --user "$user" --pass "$pass" --key "$key" --name "localhost" 2>/dev/null || true
    else
        ssh_init --host "$host" --user "$user" --pass "$pass" --key "$key" --name "$host"
    fi

    log_info "Configuring 3X-UI on ${host}"

    ssh_run "x-ui register" 2>/dev/null || {
        log_warn "x-ui register may have already been run"
    }

    local current_port
    current_port=$(ssh_run "x-ui getPort 2>/dev/null" 2>/dev/null || echo "2053")
    log_info "Current 3X-UI port: ${current_port}"

    read -rp "Enter panel port [${current_port}]: " new_port
    new_port="${new_port:-${current_port}}"

    read -rp "Admin username: " admin_user
    read -rsp "Admin password: " admin_pass
    echo ""

    ssh_run "x-ui setPort ${new_port}" 2>/dev/null || log_warn "Could not set port via CLI"
    ssh_run "x-ui register '${admin_user}' '${admin_pass}'" 2>/dev/null || log_warn "Could not set credentials via CLI"

    local cert_choice=""
    while [[ "$cert_choice" != "1" && "$cert_choice" != "2" && "$cert_choice" != "3" ]]; do
        echo "SSL certificate mode:"
        echo "  1) Let's Encrypt (requires domain)"
        echo "  2) Self-signed"
        echo "  3) None"
        read -rp "Choose [3]: " cert_choice
        cert_choice="${cert_choice:-3}"
    done

    case "$cert_choice" in
        1)
            read -rp "Domain for SSL (e.g., panel.example.com): " cert_domain
            ssh_run "x-ui cert '${cert_domain}'" 2>/dev/null || log_warn "Cert request failed"
            ;;
        2)
            ssh_run "x-ui cert self" 2>/dev/null || log_warn "Self-signed cert failed"
            ;;
        3)
            log_info "No SSL configured"
            ;;
    esac

    local db_choice=""
    while [[ "$db_choice" != "1" && "$db_choice" != "2" && "$db_choice" != "3" ]]; do
        echo "Database:"
        echo "  1) SQLite (default)"
        echo "  2) MySQL"
        echo "  3) MariaDB"
        read -rp "Choose [1]: " db_choice
        db_choice="${db_choice:-1}"
    done

    if [[ "$db_choice" != "1" ]]; then
        read -rp "DB host: " db_host
        read -rp "DB port: " db_port
        read -rp "DB name: " db_name
        read -rp "DB user: " db_user
        read -rsp "DB password: " db_pass
        echo ""
        ssh_run "x-ui setDb '${db_choice}' '${db_host}' '${db_port}' '${db_name}' '${db_user}' '${db_pass}'" 2>/dev/null || log_warn "Could not configure DB via CLI"
    fi

    log_success "3X-UI configured on ${host}"
}

function save_secrets_3xui() {
    local server_name="$1"
    local host="$2"
    local user="$3"
    local pass="$4"
    local key="$5"

    local secrets_dir="${PROJECT_ROOT}/data/servers"
    mkdir -p "$secrets_dir"
    local secrets_file="${secrets_dir}/${server_name}.json"

    if [[ ! -f "$secrets_file" ]]; then
        echo "{}" > "$secrets_file"
    fi

    local panel_url=""
    local panel_port=""
    local panel_user=""
    local panel_pass=""

    if [[ $STANDALONE -eq 1 ]]; then
        panel_url=$(x-ui getPanelUrl 2>/dev/null || echo "")
        panel_port=$(x-ui getPort 2>/dev/null || echo "")
        panel_user=$(x-ui getAdminUser 2>/dev/null || echo "")
        panel_pass=$(x-ui getAdminPass 2>/dev/null || echo "")
    else
        ssh_init --host "$host" --user "$user" --pass "$pass" --key "$key" --name "$server_name"
        panel_url=$(ssh_run "x-ui getPanelUrl 2>/dev/null" 2>/dev/null || echo "")
        panel_port=$(ssh_run "x-ui getPort 2>/dev/null" 2>/dev/null || echo "")
        panel_user=$(ssh_run "x-ui getAdminUser" 2>/dev/null || echo "")
        panel_pass=$(ssh_run "x-ui getAdminPass" 2>/dev/null || echo "")
    fi

    local key_path="$key"
    if [[ -z "$key_path" ]]; then
        local default_key="${PROJECT_ROOT:-$(pwd)}/ssh/${server_name}.key"
        if [[ -f "$default_key" ]]; then
            key_path="ssh/${server_name}.key"
        fi
    elif [[ "$key_path" == "${PROJECT_ROOT}/ssh/${server_name}.key" ]]; then
        key_path="ssh/${server_name}.key"
    fi

    python3 -c "
import json
sf = '${secrets_file}'
with open(sf) as f:
    data = json.load(f)
data['ssh_user'] = '${user}'
data['ssh_host'] = '${host}'
if '${pass}':
    data['ssh_password'] = '${pass}'
if '${key_path}':
    data['ssh_key_path'] = '${key_path}'
data['panels'] = data.get('panels', {})
data['panels']['3x-ui'] = {
    'url': '${panel_url}',
    'port': '${panel_port}',
    'admin_user': '${panel_user}',
    'admin_pass': '${panel_pass}',
}
with open(sf, 'w') as f:
    json.dump(data, f, indent=2)
"
    log_info "Secrets saved to ${secrets_file}"
}
with open(sf, 'w') as f:
    json.dump(data, f, indent=2)
"
    log_info "Secrets saved to ${secrets_file}"
}