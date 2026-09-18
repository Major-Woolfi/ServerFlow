
LOG_DIR="${LOG_DIR:-./logs}"
CURRENT_LOG_FILE=""

function log_init() {
    local server_name="$1"
    if [[ -z "$server_name" ]]; then
        echo "[logger] ERROR: server_name required" >&2
        return 1
    fi

    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local dir="${LOG_DIR}/${server_name}"
    mkdir -p "$dir"

    CURRENT_LOG_FILE="${dir}/${timestamp}.log"
    echo "[logger] Log: ${CURRENT_LOG_FILE}"
}

function log_msg() {
    local msg="$1"
    local level="${2:-INFO}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ -z "$CURRENT_LOG_FILE" ]]; then
        log_init "unnamed" &>/dev/null || true
    fi

    local entry="[${timestamp}] [${level}] ${msg}"
    echo "$entry" | tee -a "$CURRENT_LOG_FILE"
}

function log_error() {
    log_msg "$1" "ERROR"
}

function log_warn() {
    log_msg "$1" "WARN"
}

function log_success() {
    log_msg "$1" "OK"
}

function log_info() {
    log_msg "$1" "INFO"
}