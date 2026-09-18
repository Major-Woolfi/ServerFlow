set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"

function add_server_interactive() {
    echo "=== Add New Server ==="

    read -rp "Server name (alphanumeric, dash, underscore): " sname
    if ! validate_server_name "$sname"; then
        log_error "Invalid server name: $sname"
        exit 1
    fi

    if server_exists "$sname"; then
        log_error "Server '${sname}' already exists"
        exit 1
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

    local ssh_pass="" ssh_key=""
    read -rp "Use SSH key? (y/n) [n]: " use_key
    if [[ "$use_key" =~ ^[Yy] ]]; then
        local default_key="${PROJECT_ROOT}/ssh/${sname}.key"
        if [[ -f "$default_key" ]]; then
            ssh_key="ssh/${sname}.key"
            log_info "Using existing key: ${default_key}"
        else
            read -rp "Path to SSH key: " key_path
            if [[ ! -f "$key_path" ]]; then
                log_error "Key file not found: $key_path"
                exit 1
            fi
            local ssh_dir="${PROJECT_ROOT}/ssh"
            mkdir -p "$ssh_dir"
            cp "$key_path" "${ssh_dir}/${sname}.key"
            ssh_key="ssh/${sname}.key"
            log_success "Copied key to ${ssh_dir}/${sname}.key"
        fi
    else
        read -rsp "SSH password: " ssh_pass
        echo ""
    fi

    local has_3xui="n"
    local has_aapanel="n"
    read -rp "Has 3X-UI panel? (y/n) [n]: " has_3xui
    read -rp "Has aaPanel? (y/n) [n]: " has_aapanel

    SF_PROJECT="$PROJECT_ROOT" \
    SF_SERVER="$sname" \
    SF_USER="$suser" \
    SF_HOST="$shost" \
    SF_PASS="$ssh_pass" \
    SF_KEY="$ssh_key" \
    SF_TYPE="$stype" \
    SF_HAS_3XUI="$has_3xui" \
    SF_HAS_AAPANEL="$has_aapanel" \
    python3 << 'PYEOF'
import json, os

project = os.environ.get("SF_PROJECT", "")
server_name = os.environ.get("SF_SERVER", "")
ssh_user = os.environ.get("SF_USER", "root")
ssh_host = os.environ.get("SF_HOST", "")
ssh_pass = os.environ.get("SF_PASS", "")
ssh_key = os.environ.get("SF_KEY", "")
server_type = os.environ.get("SF_TYPE", "node")
has_3xui = os.environ.get("SF_HAS_3XUI", "n") in ("y", "Y", "yes")
has_aapanel = os.environ.get("SF_HAS_AAPANEL", "n") in ("y", "Y", "yes")

secret_path = os.path.join(project, "data", "servers", f"{server_name}.json")
config_path = os.path.join(project, "config", "servers.json")

data = {
    "type": server_type,
    "host": ssh_host,
    "ssh_user": ssh_user,
}
if ssh_pass:
    data["ssh_password"] = ssh_pass
if ssh_key:
    data["ssh_key_path"] = ssh_key

panels = {}
if has_3xui:
    panels["3x-ui"] = {}
if has_aapanel:
    panels["aaPanel"] = {}
data["panels"] = panels

config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)
config[server_name] = {
    "type": server_type,
    "host": ssh_host,
    "ssh_user": ssh_user,
}

os.makedirs(os.path.dirname(secret_path), exist_ok=True)
with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
with open(secret_path, "w") as f:
    json.dump(data, f, indent=2)
PYEOF

    log_success "Server '${sname}' added successfully"
    log_info "Config: ${PROJECT_ROOT}/data/servers/${sname}.json"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    add_server_interactive "$@"
fi