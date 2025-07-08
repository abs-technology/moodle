#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# Load balancer setup script for Absi Technology Moodle
. /scripts/lib/logging.sh

info "Setting up load balancer configuration..."

# Create session directory for shared sessions
SESSIONS_DIR="/var/www/moodledata/sessions"
if [[ ! -d "$SESSIONS_DIR" ]]; then
    info "Creating shared sessions directory: $SESSIONS_DIR"
    mkdir -p "$SESSIONS_DIR"
    chown -R absiuser:absiuser "$SESSIONS_DIR"
    chmod 755 "$SESSIONS_DIR"
fi

# Set proper permissions for moodledata
chown -R absiuser:absiuser /var/www/moodledata
find /var/www/moodledata -type d -exec chmod 755 {} +
find /var/www/moodledata -type f -exec chmod 644 {} +

info "Load balancer configuration completed" 