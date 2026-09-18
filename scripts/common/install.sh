set -euo pipefail

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"

function install_3xui_remote() {
    local host="$1"
    local user="$2"
    local pass="${3:-}"
    local key="${4:-}"

    if [[ $STANDALONE -eq 1 ]]; then
        log_info "Installing 3X-UI (standalone)..."
        if ! bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh); then
            log_error "3X-UI installation failed"
            return 1
        fi
        log_success "3X-UI installed"
        return 0
    fi

    log_info "Installing 3X-UI on ${user}@${host}"
    ssh_init --host "$host" --user "$user" --pass "$pass" --key "$key" --name "$host"

    if ! ssh_run "bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)"; then
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
        local install_cmd='URL=https://www.aapanel.com/script/install_panel_en.sh && if [ -f /usr/bin/curl ];then curl -ksSO $URL;else wget --no-check-certificate -O install_panel_en.sh $URL;fi;bash install_panel_en.sh ipssl'
        if ! bash -c "$install_cmd"; then
            log_error "aaPanel installation failed"
            return 1
        fi
        log_success "aaPanel installed"
        return 0
    fi

    log_info "Installing aaPanel on ${user}@${host}"
    ssh_init --host "$host" --user "$user" --pass "$pass" --key "$key" --name "$host"

    if ! ssh_run 'URL=https://www.aapanel.com/script/install_panel_en.sh && if [ -f /usr/bin/curl ];then curl -ksSO $URL;else wget --no-check-certificate -O install_panel_en.sh $URL;fi;bash install_panel_en.sh ipssl'; then
        log_error "aaPanel installation failed on ${host}"
        return 1
    fi

    log_success "aaPanel installed on ${host}"
    return 0
}
