#!/bin/bash
# Copyright Absi Technology. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

RESET='\033[0m'
RED='\033[38;5;1m'
GREEN='\033[38;5;2m'
YELLOW='\033[38;5;3m'
MAGENTA='\033[38;5;5m'
CYAN='\033[38;5;6m'

#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Icons
SUCCESS="[✓]"
FAIL="[✗]"
WARNING="[!]"
CLOCK="[t]"

# Test data (replace with actual values)
SUCCESS_COUNT=100
RATE_LIMITED_COUNT=5
BLOCKED_COUNT=2
ERROR_COUNT=1
TEST_DURATION=67
ACTUAL_RATE="90"

# Print colored line
print_line() {
    printf "%b%s%b\n" "$1" "$2" "$NC"
}

# Header first line: title
print_title_line() {
    local title="$1"
    local prefix="─ "
    local suffix=" ─"
    local left="╭"
    local right="╮"
    
    local content="${prefix}${title}${suffix}"
    local filler_length=$((50 - 2 - ${#content}))
    local filler=$(printf '─%.0s' $(seq 1 "$filler_length"))
    
    printf "%b%s%s%s%b\n" "$WHITE" "$left" "$content$filler" "$right" "$NC"
}

# Footer
print_footer_line() {
    local middle=$(printf '─%.0s' $(seq 1 48))
    print_line "$WHITE" "╰${middle}╯"
}

# Content line in table
print_fixed_box_line() {
    local icon="$1"
    local label="$2"
    local value="$3"
    local color="$4"
    
    local text="${icon} ${label}: ${value}"
    local padding=$((46 - ${#text}))
    local pad=$(printf '%*s' "$padding")
    
    printf "%b│ %b%s%s%b │%b\n" "$WHITE" "$color" "$text" "$pad" "$NC" "$NC"
}


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
