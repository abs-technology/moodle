#!/bin/bash
# Moodle 5.x path layout (verified against stable502 tarball):
#   ${MOODLE_DIR}/public/          web root (DocumentRoot)
#   ${MOODLE_DIR}/public/version.php
#   ${MOODLE_DIR}/admin/cli/       CLI scripts (NOT under public/)

. /scripts/lib/logging.sh

moodle_init_paths() {
    local base="${1:-${MOODLE_DIR:-/var/www/html}}"

    if [[ ! -f "${base}/public/version.php" ]]; then
        error "Moodle 5.x layout required: ${base}/public/version.php not found"
        return 1
    fi

    export MOODLE_LAYOUT=5
    export MOODLE_WEB_ROOT="${base}/public"
    export MOODLE_CLI_DIR="${base}/admin/cli"
    export MOODLE_VERSION_FILE="${base}/public/version.php"
    return 0
}

moodle_cli_script() {
    local script_name="$1"
    local base="${2:-${MOODLE_DIR:-/var/www/html}}"
    local path

    if [[ -z "${MOODLE_CLI_DIR:-}" ]] || [[ "${MOODLE_VERSION_FILE:-}" != "${base}/public/version.php" ]]; then
        moodle_init_paths "$base" || return 1
    fi

    path="${MOODLE_CLI_DIR}/${script_name}"
    if [[ ! -f "$path" ]]; then
        error "Moodle CLI script not found: $path"
        return 1
    fi
    echo "$path"
}

moodle_version_file() {
    local base="${1:-${MOODLE_DIR:-/var/www/html}}"

    if [[ -f "${base}/public/version.php" ]]; then
        echo "${base}/public/version.php"
        return 0
    fi
    return 1
}

moodle_read_release() {
    local vfile="$1"
    _parse_version_php_var "$vfile" "release" | awk '{print $1}'
}

_parse_version_php_var() {
    local file=$1
    local var=$2
    sed -nE "/^[[:space:]]*\\\$${var}[[:space:]]*=/{
        s/^[^=]*=[[:space:]]*//
        s/[[:space:]]*;.*$//
        s/^[[:space:]]+//
        s/[[:space:]]+$//
        s/^['\"]+//
        s/['\"]+$//
        p
        q
    }" "$file"
}
