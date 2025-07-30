#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh
. /scripts/lib/config.sh
. /scripts/lib/service.sh

# Load centralized configuration
load_config

# Function to handle TERM signal to stop child processes
_forwardTerm() {
    warn "Caught signal SIGTERM, passing it to child processes..."
    kill "$(jobs -p)" # Stop child processes running in background
    wait # Wait for all child processes to finish
    exit $?
}
trap _forwardTerm TERM

# Start Moodle cron with traditional approach (runs script every N minutes)
info "** Starting Moodle traditional cron process **"

# Convert MOODLE_CRON_MINUTES to seconds for traditional cron scheduling
CRON_SECONDS=$((MOODLE_CRON_MINUTES * 60))
if [ $CRON_SECONDS -lt 60 ]; then
    CRON_SECONDS=60
fi

# Always start fresh cron process
info "Starting Moodle traditional cron loop (running every ${MOODLE_CRON_MINUTES} minutes)"

# Remove old PID file if exists
rm -f /tmp/moodle-cron.pid

# Start traditional cron loop that runs script every MOODLE_CRON_MINUTES
{
    while true; do
        echo "$(date): Starting cron run..."
        cd /var/www/html
        /usr/bin/php admin/cli/cron.php
        echo "$(date): Cron completed, sleeping for ${CRON_SECONDS} seconds..."
        sleep $CRON_SECONDS
    done
} >> /tmp/moodle-cron.log 2>&1 &

CRON_LOOP_PID=$!
echo $CRON_LOOP_PID > /tmp/moodle-cron.pid
info "Moodle cron loop started (PID: $CRON_LOOP_PID) running every ${MOODLE_CRON_MINUTES} minutes"

# Verify cron loop is running
sleep 2
if kill -0 $CRON_LOOP_PID 2>/dev/null; then
    info "✅ Moodle cron loop confirmed running every ${MOODLE_CRON_MINUTES} minutes"
else
    warn "❌ Moodle cron loop failed to start"
fi

info "** Starting PHP-FPM **"
php-fpm${PHP_VERSION} -F & # Run PHP-FPM in background

info "** Starting Apache **"
exec apache2 -DFOREGROUND # Run Apache in foreground (main process)
