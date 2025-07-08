#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh
. /scripts/lib/filesystem.sh

WEB_SERVER_DAEMON_USER="absiuser"
WEB_SERVER_DAEMON_GROUP="absiuser"

debug "Starting Apache setup script"
debug "Current directory: $(pwd)"
debug "Current user: $(whoami)"

info "Starting Apache setup for Absi Technology..."

debug "Checking if user $WEB_SERVER_DAEMON_USER exists..."
ensure_user_exists "$WEB_SERVER_DAEMON_USER" "$WEB_SERVER_DAEMON_GROUP"
debug "User setup completed with exit code: $?"

debug "Creating /var/log/apache2 directory..."
ensure_dir_exists "/var/log/apache2" "$WEB_SERVER_DAEMON_USER" "$WEB_SERVER_DAEMON_GROUP" "775"
debug "Directory creation completed with exit code: $?"

debug "Creating /var/run/apache2 directory..."
ensure_dir_exists "/var/run/apache2" "$WEB_SERVER_DAEMON_USER" "$WEB_SERVER_DAEMON_GROUP" "775"
debug "Directory creation completed with exit code: $?"

debug "Checking Apache configuration..."
if [ -f "/etc/apache2/apache2.conf" ]; then
    debug "Apache2 configuration file exists"
else
    debug "Apache2 configuration file not found"
fi

debug "Checking Apache modules..."
ls -la /etc/apache2/mods-enabled/ >/dev/null 2>&1 || debug "No enabled modules found"

info "Apache setup finished."
debug "Apache setup script completed"
