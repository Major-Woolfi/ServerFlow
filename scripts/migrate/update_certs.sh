set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_ROOT}/scripts/common/logger.sh"
source "${PROJECT_ROOT}/scripts/common/validate.sh"
source "${PROJECT_ROOT}/scripts/common/ssh.sh"

function update_certs() {
    local host="$1"
    local user="${2:-root}"
    local pass="${3:-}"
    local key="${4:-}"

    log_init "$host"
    log_info "=== Updating certificates on ${host} ==="

    ssh_init --host "$host" --user "$user" --pass "$pass" --key "$key" --name "$host"

    log_info "Checking/renewing Let's Encrypt certs..."
    ssh_run "certbot renew --quiet --post-hook 'systemctl reload nginx 2>/dev/null || systemctl reload httpd 2>/dev/null || true'" 2>/dev/null || log_warn "certbot renew failed"

    log_info "Reloading Nginx..."
    ssh_run "nginx -t && systemctl reload nginx" 2>/dev/null || log_warn "Nginx reload failed"

    log_info "Updating aaPanel SSL..."
    ssh_run "bash /www/server/panel/panel SSL" 2>/dev/null || ssh_run "python3 /www/server/panel/panel SSL" 2>/dev/null || log_warn "aaPanel SSL update failed"

    log_success "=== Certificates updated on ${host} ==="
}

update_certs "$@"