#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

# Colors for log messages
LOG_INFO_COLOR='\033[0;34m'  # Blue
LOG_WARN_COLOR='\033[0;33m'  # Yellow
LOG_ERROR_COLOR='\033[0;31m' # Red
LOG_DEBUG_COLOR='\033[0;36m' # Cyan
LOG_RESET='\033[0m'          # Reset color

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Default log level
LOG_LEVEL=${LOG_LEVEL:-1}  # Default to INFO level

# Logging functions
log_debug() {
    if [ ${LOG_LEVEL} -le ${LOG_LEVEL_DEBUG} ]; then
        echo -e "${LOG_DEBUG_COLOR}[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*${LOG_RESET}" >&2
    fi
}

log_info() {
    if [ ${LOG_LEVEL} -le ${LOG_LEVEL_INFO} ]; then
        echo -e "${LOG_INFO_COLOR}[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*${LOG_RESET}"
    fi
}

log_warn() {
    if [ ${LOG_LEVEL} -le ${LOG_LEVEL_WARN} ]; then
        echo -e "${LOG_WARN_COLOR}[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*${LOG_RESET}" >&2
    fi
}

log_error() {
    if [ ${LOG_LEVEL} -le ${LOG_LEVEL_ERROR} ]; then
        echo -e "${LOG_ERROR_COLOR}[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*${LOG_RESET}" >&2
    fi
}

# Function to exit with error
exit_with_error() {
    log_error "$1"
    exit 1
} 