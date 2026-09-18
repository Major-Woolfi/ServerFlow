set -euo pipefail

source "${PROJECT_ROOT}/scripts/common/bootstrap.sh"
source "${PROJECT_ROOT}/scripts/common/validate.sh"
source "${PROJECT_ROOT}/scripts/common/ssh.sh"

function sync_data() {
    local old_host="$1"
    local new_host="$2"
    local old_user="${3:-root}"
    local new_user="${4:-root}"
    local mode="${5:-native}"

    log_init "migrate"
    log_info "=== Syncing data: ${old_host} to ${new_host} ==="
    log_info "Mode: ${mode}"

    local dirs_to_sync=(
        "/etc"
        "/var/www"
        "/var/lib/mysql"
        "/var/lib/redis"
        "/home"
        "/root"
        "/usr/local"
        "/www"
    )

    case "$mode" in
        native)
            log_info "Using native mode (direct rsync)"
            for dir in "${dirs_to_sync[@]}"; do
                log_info "Syncing ${dir}..."
                rsync -avz --progress -e "ssh -o StrictHostKeyChecking=accept-new" \
                    "${old_user}@${old_host}:${dir}/" \
                    "${new_user}@${new_host}:${dir}/" \
                    2>&1 | tee -a "$CURRENT_LOG_FILE" || log_warn "Failed to sync ${dir}"
            done
            ;;
        bridge)
            log_info "Using bridge mode (via localhost)"
            log_info "Step 1: Downloading from old server..."
            local tmp_dir
            tmp_dir=$(mktemp -d)
            for dir in "${dirs_to_sync[@]}"; do
                local safe_name
                safe_name=$(echo "$dir" | tr '/' '_')
                log_info "Downloading ${dir}..."
                rsync -avz --progress -e "ssh -o StrictHostKeyChecking=accept-new" \
                    "${old_user}@${old_host}:${dir}/" \
                    "${tmp_dir}/${safe_name}/" \
                    2>&1 | tee -a "$CURRENT_LOG_FILE" || log_warn "Failed to download ${dir}"
            done

            log_info "Step 2: Uploading to new server..."
            for dir in "${dirs_to_sync[@]}"; do
                local safe_name
                safe_name=$(echo "$dir" | tr '/' '_')
                log_info "Uploading ${dir}..."
                rsync -avz --progress \
                    "${tmp_dir}/${safe_name}/" \
                    "${new_user}@${new_host}:${dir}/" \
                    2>&1 | tee -a "$CURRENT_LOG_FILE" || log_warn "Failed to upload ${dir}"
            done

            rm -rf "$tmp_dir"
            log_success "Bridge sync complete"
            ;;
        *)
            log_error "Unknown mode: $mode"
            exit 1
            ;;
    esac

    log_success "=== Data sync complete ==="
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    sync_data "$@"
fi