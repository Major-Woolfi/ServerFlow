set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

export PROJECT_ROOT

LOG_DIR="${LOG_DIR:-${PROJECT_ROOT}/logs}"
export LOG_DIR

source "${PROJECT_ROOT}/scripts/common/logger.sh"
source "${PROJECT_ROOT}/scripts/common/validate.sh"
source "${PROJECT_ROOT}/scripts/common/ssh.sh"

STANDALONE=0
if [[ -d /etc/x-ui/ ]]; then
    STANDALONE=1
    PROJECT_ROOT="$(pwd)"
    export PROJECT_ROOT
    log_info "Standalone mode: running on target server"
fi

if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${PROJECT_ROOT}/.env"
    set +a
fi

function server_config_path() {
    local name="$1"
    echo "${PROJECT_ROOT}/data/servers/${name}.json"
}

function read_server_config() {
    local name="$1"
    local path
    path=$(server_config_path "$name")
    if [[ ! -f "$path" ]]; then
        echo "NOT_FOUND"
        return 1
    fi
    python3 -c "
import json, sys
with open('${path}') as f:
    data = json.load(f)
for k, v in data.items():
    if isinstance(v, dict):
        items = []
        for sk, sv in v.items():
            items.append(f'{sk}={sv}')
        print(f'{k}=' + '|'.join(items))
    else:
        print(f'{k}={v}')
" 2>/dev/null
}

function server_exists() {
    local name="$1"
    local path
    path=$(server_config_path "$name")
    [[ -f "$path" ]]
}

function list_servers() {
    local dir="${PROJECT_ROOT}/data/servers"
    if [[ ! -d "$dir" ]]; then
        return 0
    fi
    for f in "$dir"/*.json; do
        [[ -f "$f" ]] || continue
        basename "$f" .json
    done
}

function load_server_config() {
    local name="$1"
    local path
    path=$(server_config_path "$name")
    if [[ ! -f "$path" ]]; then
        log_error "Server config not found: ${path}"
        return 1
    fi
    python3 -c "
import json
with open('${path}') as f:
    data = json.load(f)
for k, v in data.items():
    if isinstance(v, dict):
        for sk, sv in v.items():
            print(f'{k}.{sk}={sv}')
    else:
        print(f'{k}={v}')
" 2>/dev/null
}

function write_server_config() {
    local name="$1"
    local json_data="$2"
    local dir
    dir=$(server_config_path "$name" | xargs dirname)
    mkdir -p "$dir"
    echo "$json_data" > "$(server_config_path "$name")"
}

function update_server_config_field() {
    local name="$1"
    local field="$2"
    local value="$3"
    local path
    path=$(server_config_path "$name")
    if [[ ! -f "$path" ]]; then
        log_error "Server config not found: ${path}"
        return 1
    fi
    python3 -c "
import json
with open('${path}') as f:
    data = json.load(f)
parts = '${field}'.split('.')
d = data
for p in parts[:-1]:
    d = d.setdefault(p, {})
d[parts[-1]] = '${value}'
with open('${path}', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
}

function config_servers_index() {
    echo "${PROJECT_ROOT}/config/servers.json"
}

function read_servers_index() {
    local path
    path=$(config_servers_index)
    if [[ ! -f "$path" ]]; then
        echo "{}"
        return
    fi
    python3 -c "
import json
with open('${path}') as f:
    print(json.dumps(json.load(f), indent=2))
" 2>/dev/null || echo "{}"
}

function write_servers_index() {
    local json_data="$1"
    local path
    path=$(config_servers_index)
    local dir
    dir=$(dirname "$path")
    mkdir -p "$dir"
    echo "$json_data" > "$path"
}