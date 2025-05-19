#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

set -eo pipefail

# Default values
MOODLE_HEALTHCHECK_URL=${MOODLE_HEALTHCHECK_URL:-"http://localhost/"}
TIMEOUT=${TIMEOUT:-10}
MAX_RETRIES=${MAX_RETRIES:-3}
RETRY_INTERVAL=${RETRY_INTERVAL:-5}

# Function to log messages to stderr so they appear in container logs
log_info() {
    echo "[HEALTHCHECK] [INFO] $1" >&2
}

log_error() {
    echo "[HEALTHCHECK] [ERROR] $1" >&2
}

# Function to check if Apache is running
check_apache() {
    log_info "Checking Apache process..."
    if ! pgrep -x "apache2" > /dev/null; then
        log_error "Apache process is not running"
        return 1
    fi
    log_info "Apache is running"
    return 0
}

# Function to check if PHP is working
check_php() {
    log_info "Checking PHP functionality..."
    if ! php -r 'echo "PHP OK\n";' 2>/dev/null; then
        log_error "PHP is not working properly"
        return 1
    fi
    log_info "PHP is working properly"
    return 0
}

# Function to check if Moodle is responding
check_moodle() {
    local retry=0
    local status_code
    
    log_info "Checking Moodle response at $MOODLE_HEALTHCHECK_URL"
    
    while [ $retry -lt $MAX_RETRIES ]; do
        log_info "Attempt $((retry+1))/$MAX_RETRIES: Sending request to $MOODLE_HEALTHCHECK_URL"
        
        status_code=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT "$MOODLE_HEALTHCHECK_URL" 2>/dev/null || echo "000")
        
        if [ "$status_code" = "200" ] || [ "$status_code" = "303" ]; then
            log_info "Moodle healthcheck passed with status code: $status_code"
            return 0
        fi
        
        log_error "Moodle healthcheck failed with status code: $status_code (attempt $((retry+1))/$MAX_RETRIES)"
        retry=$((retry+1))
        
        if [ $retry -lt $MAX_RETRIES ]; then
            log_info "Waiting $RETRY_INTERVAL seconds before next attempt..."
            sleep $RETRY_INTERVAL
        fi
    done
    
    log_error "Moodle healthcheck failed after $MAX_RETRIES attempts"
    return 1
}

# Main healthcheck logic
main() {
    log_info "Starting Moodle healthcheck..."
    
    # Check if Apache is running
    if ! check_apache; then
        log_error "Healthcheck failed: Apache issue"
        exit 1
    fi
    
    # Check if PHP is working
    if ! check_php; then
        log_error "Healthcheck failed: PHP issue"
        exit 1
    fi
    
    # Check if Moodle is responding
    if ! check_moodle; then
        log_error "Healthcheck failed: Moodle response issue"
        exit 1
    fi
    
    log_info "Healthcheck completed successfully"
    exit 0
}

# Run main function
main 