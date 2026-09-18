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

    read -rp "aaPanel admin username: " admin_user
    read -rsp "aaPanel admin password: " admin_pass
    echo ""

    ssh_run "python3 -c \"
import json
info_path = '/www/server/panel/data/info.json'
try:
    with open(info_path) as f:
        info = json.load(f)
except:
    info = {}
info['admin'] = {'username': '${admin_user}', 'password': '${admin_pass}'}
with open(info_path, 'w') as f:
    json.dump(info, f, indent=2)
\"" 2>/dev/null || log_warn "Could not update aaPanel config"

    log_success "aaPanel configured"
}