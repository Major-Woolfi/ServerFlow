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

function install_3xui_remote() {
    local host="$1"
    local user="$2"
    local pass="${3:-}"
    local key="${4:-}"

    if [[ $STANDALONE -eq 1 ]]; then
        log_info "Installing 3X-UI (standalone)..."
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        if [[ $? -ne 0 ]]; then
            log_error "3X-UI installation failed"
            return 1
        fi
        log_success "3X-UI installed"
        return 0
    fi

    log_info "Installing 3X-UI on ${user}@${host}"
    ssh_init --host "$host" --user "$user" --pass "$pass" --key "$key" --name "$host"

    ssh_run "bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)"
    if [[ $? -ne 0 ]]; then
        log_error "3X-UI installation failed on ${host}"
        return 1
    fi

    log_success "3X-UI installed on ${host}"
    return 0
}

function install_aapanel_remote() {
    local host="$1"
    local user="$2"
    local pass="${3:-}"
    local key="${4:-}"

    if [[ $STANDALONE -eq 1 ]]; then
        log_info "Installing aaPanel (standalone)..."
        URL=https://www.aapanel.com/script/install_panel_en.sh && if [ -f /usr/bin/curl ];then curl -ksSO $URL;else wget --no-check-certificate -O install_panel_en.sh $URL;fi;bash install_panel_en.sh ipssl
        if [[ $? -ne 0 ]]; then
            log_error "aaPanel installation failed"
            return 1
        fi
        log_success "aaPanel installed"
        return 0
    fi

    log_info "Installing aaPanel on ${user}@${host}"

    ssh_init --host "$host" --user "$user" --pass "$pass" --key "$key" --name "$host"

    ssh_run 'URL=https://www.aapanel.com/script/install_panel_en.sh && if [ -f /usr/bin/curl ];then curl -ksSO $URL;else wget --no-check-certificate -O install_panel_en.sh $URL;fi;bash install_panel_en.sh ipssl'

    if [[ $? -ne 0 ]]; then
        log_error "aaPanel installation failed on ${host}"
        return 1
    fi

    log_success "aaPanel installed on ${host}"
    return 0
}
