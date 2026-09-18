set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"

function config_aapanel_remote() {
    if [[ $STANDALONE -eq 1 ]]; then
        ssh_init --host "localhost" --name "localhost" 2>/dev/null || true
    else
        local host="$1"
        local user="$2"
        local pass="${3:-}"
        local key="${4:-}"
        ssh_init --host "$host" --user "$user" --pass "$pass" --key "$key" --name "$host"
    fi

    log_info "Configuring aaPanel on localhost"

    local admin_user="admin"
    local admin_pass=""

    if [[ $STANDALONE -eq 1 ]]; then
        read -rp "aaPanel admin username [admin]: " admin_user
        admin_user="${admin_user:-admin}"
        read -rsp "aaPanel admin password: " admin_pass
        echo ""
    else
        local panel_info
        panel_info=$(ssh_run "cat /www/server/panel/data/info.json 2>/dev/null" 2>/dev/null || echo "{}")
        admin_user=$(echo "$panel_info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('admin',{}).get('username','admin'))" 2>/dev/null || echo "admin")
        read -rsp "aaPanel admin password [leave empty to keep]: " admin_pass
        echo ""
    fi

    if [[ -n "$admin_pass" ]]; then
        local admin_pass_b64
        admin_pass_b64=$(printf '%s' "$admin_pass" | base64 | tr -d '\n')

        ssh_run "python3 -c \"
import json, base64
info_path = '/www/server/panel/data/info.json'
try:
    with open(info_path) as f:
        info = json.load(f)
except:
    info = {}
admin_pass = base64.b64decode('${admin_pass_b64}').decode('utf-8')
info['admin'] = {'username': '${admin_user}', 'password': admin_pass}
with open(info_path, 'w') as f:
    json.dump(info, f, indent=2)
\"" 2>/dev/null || log_warn "Could not update aaPanel config"
    fi

    log_success "aaPanel configured"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    config_aapanel_remote "$@"
fi