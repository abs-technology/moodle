#!/bin/bash
# Copyright Absi Technology. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

RESET='\033[0m'
RED='\033[38;5;1m'
GREEN='\033[38;5;2m'
YELLOW='\033[38;5;3m'
MAGENTA='\033[38;5;5m'
CYAN='\033[38;5;6m'

stderr_print() {
    printf "%b\\n" "${*}" >&2
}

log() {
    local module_name="${MODULE_NAME:-AbsiApp}"
    local color_bool="${COLOR_LOGS:-true}"

    shopt -s nocasematch
    if [[ "$color_bool" = 1 || "$color_bool" =~ ^(yes|true)$ ]]; then
        stderr_print "${CYAN}${module_name} ${MAGENTA}$(date "+%T.%2N ")${RESET}${*}"
    else
        stderr_print "${module_name} $(date "+%T.%2N ")${*}"
    fi
}

info() {
    local msg_color=""
    shopt -s nocasematch
    if [[ "${COLOR_LOGS:-true}" = 1 || "${COLOR_LOGS:-true}" =~ ^(yes|true)$ ]];then
        msg_color="$GREEN"
    fi
    log "${msg_color}INFO ${RESET} ==> ${*}"
}

warn() {
    local msg_color=""
    shopt -s nocasematch
    if [[ "${COLOR_LOGS:-true}" = 1 || "${COLOR_LOGS:-true}" =~ ^(yes|true)$ ]];then
        msg_color="$YELLOW"
    fi
    log "${msg_color}WARN ${RESET} ==> ${*}"
}

error() {
    local msg_color=""
    shopt -s nocasematch
    if [[ "${COLOR_LOGS:-true}" = 1 || "${COLOR_LOGS:-true}" =~ ^(yes|true)$ ]];then
        msg_color="$RED"
    fi
    log "${msg_color}ERROR${RESET} ==> ${*}"
}

debug() {
    local msg_color=""
    shopt -s nocasematch
    if [[ "${COLOR_LOGS:-true}" = 1 || "${COLOR_LOGS:-true}" =~ ^(yes|true)$ ]] ;then
        msg_color="$MAGENTA"
    fi
    local debug_bool="${DEBUG:-false}"
    if [[ "$debug_bool" = 1 || "$debug_bool" =~ ^(yes|true)$ ]]; then
        log "${msg_color}DEBUG${RESET} ==> ${*}"
    fi
}

indent() {
    local string="${1:-}"
    local num="${2:?missing num}"
    local char="${3:-" "}"
    local indent_unit=""
    for ((i = 0; i < num; i++)); do
        indent_unit="${indent_unit}${char}"
    done
    echo "$string" | sed "s/^/${indent_unit}/"
}

# Enable debug mode by default
export DEBUG=false
export COLOR_LOGS=true
export MODULE_NAME="abstechnology-moodle"

# Log library initialization
debug "Logging library initialized"
debug "Debug mode: $DEBUG"
debug "Color logs: $COLOR_LOGS"
debug "Module name: $MODULE_NAME"
