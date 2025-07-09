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

# Create session directory for shared sessions
SESSIONS_DIR="${MOODLE_DATA_DIR}/sessions"
if [[ ! -d "$SESSIONS_DIR" ]]; then
    info "Creating shared sessions directory: $SESSIONS_DIR"
    mkdir -p "$SESSIONS_DIR"
    chown -R $APP_USER:$APP_GROUP "$SESSIONS_DIR"
    chmod 755 "$SESSIONS_DIR"
fi

# Set proper permissions for moodledata
chown -R $APP_USER:$APP_GROUP "$MOODLE_DATA_DIR"
find "$MOODLE_DATA_DIR" -type d -exec chmod 755 {} +
find "$MOODLE_DATA_DIR" -type f -exec chmod 644 {} +

info "Load balancer configuration completed" 