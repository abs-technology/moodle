#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# Load balancer setup script for Absi Technology Moodle
. /scripts/lib/logging.sh
. /scripts/lib/config.sh

# Load centralized configuration
load_config

info "Setting up load balancer configuration..."
debug "MOODLE_REVERSEPROXY: ${MOODLE_REVERSEPROXY}"

if [[ "$MOODLE_REVERSEPROXY" == "yes" ]]; then
    info "Load balancer mode enabled - configuring shared resources"
    
    # Create session directory for shared sessions
    SESSIONS_DIR="${MOODLE_DATA_DIR}/sessions"
    if [[ ! -d "$SESSIONS_DIR" ]]; then
        info "Creating shared sessions directory: $SESSIONS_DIR"
        mkdir -p "$SESSIONS_DIR"
        chown -R $APP_USER:$APP_GROUP "$SESSIONS_DIR"
        chmod 755 "$SESSIONS_DIR"
    fi
    
    # Set proper permissions for moodledata (shared storage)
    chown -R $APP_USER:$APP_GROUP "$MOODLE_DATA_DIR"
    find "$MOODLE_DATA_DIR" -type d -exec chmod 755 {} +
    find "$MOODLE_DATA_DIR" -type f -exec chmod 644 {} +
    
    info "Load balancer shared resources configured"
else
    info "Load balancer mode disabled - using local resources only"
    
    # Still need to set basic permissions for moodledata
    chown -R $APP_USER:$APP_GROUP "$MOODLE_DATA_DIR"
    find "$MOODLE_DATA_DIR" -type d -exec chmod 755 {} +
    find "$MOODLE_DATA_DIR" -type f -exec chmod 644 {} +
    
    info "Local resources configured"
fi

info "Load balancer configuration completed" 