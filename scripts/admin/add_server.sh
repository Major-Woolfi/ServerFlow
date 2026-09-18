set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_ROOT}/scripts/common/logger.sh"
source "${PROJECT_ROOT}/scripts/common/validate.sh"
source "${PROJECT_ROOT}/scripts/common/ssh.sh"

function add_server_interactive() {
    echo "=== Add New Server ==="

    read -rp "Server name (alphanumeric, dash, underscore): " sname
    if ! validate_server_name "$sname"; then
        log_error "Invalid server name: $sname"
        exit 1
    fi

    if [[ -f "${PROJECT_ROOT}/config/servers.json" ]]; then
        if python3 -c "import json,sys; d=json.load(open('${PROJECT_ROOT}/config/servers.json')); sys.exit(0 if '${sname}' in d else 1)" 2>/dev/null; then
            log_error "Server '${sname}' already exists"
            exit 1
        fi
    fi

    read -rp "Server host (IP or domain): " shost
    if ! validate_ip "$shost" && ! validate_hostname "$shost"; then
        log_error "Invalid host: $shost"
        exit 1
    fi

    read -rp "Server type (node/main): " stype
    case "$stype" in
        node|main) ;;
        *) log_error "Invalid type: $stype"; exit 1 ;;
    esac

    read -rp "SSH user [root]: " suser
    suser="${suser:-root}"

    read -rp "Use SSH key? (y/n): " use_key
    local ssh_pass="" ssh_key=""
    if [[ "$use_key" =~ ^[Yy] ]]; then
        read -rp "Path to SSH key: " ssh_key
        if [[ ! -f "$ssh_key" ]]; then
            log_error "Key file not found: $ssh_key"
            exit 1
        fi
        local ssh_dir="${PROJECT_ROOT}/ssh"
        mkdir -p "$ssh_dir"
        cp "$ssh_key" "${ssh_dir}/${sname}.key"
        ssh_key="ssh/${sname}.key"
    else
        read -rsp "SSH password: " ssh_pass
        echo ""
    fi

    read -rp "Has 3X-UI panel? (y/n): " has_3xui
    read -rp "Has aaPanel? (y/n): " has_aapanel

    local tmp_secret
    tmp_secret=$(mktemp)
    python3 -c "
import json
secrets = {
    'ssh_user': '${suser}',
    'ssh_host': '${shost}',
}
if '${ssh_pass}':
    secrets['ssh_password'] = '${ssh_pass}'
if '${ssh_key}':
    secrets['ssh_key_path'] = '${ssh_key}'
panels = {}
if '${has_3xui}' in ('y','Y','yes'):
    panels['3x-ui'] = {}
if '${has_aapanel}' in ('y','Y','yes'):
    panels['aaPanel'] = {}
secrets['panels'] = panels
with open('${tmp_secret}', 'w') as f:
    json.dump(secrets, f, indent=2)
"

    python3 -c "
import json, os
config_path = '${PROJECT_ROOT}/config/servers.json'
secret_path = '${PROJECT_ROOT}/data/servers/${sname}.json'
config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)
config['${sname}'] = {
    'type': '${stype}',
    'host': '${shost}',
    'ssh_user': '${suser}',
}
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
os.makedirs('${PROJECT_ROOT}/data/servers', exist_ok=True)
with open(secret_path, 'w') as f:
    f.write(open('${tmp_secret}').read())
"
    rm -f "$tmp_secret"

    log_success "Server '${sname}' added successfully"
    log_info "Secrets saved to: ${PROJECT_ROOT}/data/servers/${sname}.json"
    log_info "Config updated in: ${PROJECT_ROOT}/config/servers.json"
}

add_server_interactive "$@"