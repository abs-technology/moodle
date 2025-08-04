#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh
. /scripts/lib/config.sh
. /scripts/lib/service.sh

# Load centralized configuration
load_config

# Hàm xử lý tín hiệu TERM để dừng các tiến trình con
_forwardTerm() {
    warn "Caught signal SIGTERM, passing it to child processes..."
    kill "$(jobs -p)" # Dừng các tiến trình con đã chạy trong background
    wait # Chờ tất cả các tiến trình con kết thúc
    exit $?
}
trap _forwardTerm TERM

# Cron is now handled by keep-alive process started in entrypoint.sh
info "** Setting up continuous Moodle cron monitoring **"

# Function to start cron
start_cron() {
    # Validate MOODLE_CRON_MINUTES is a positive number
    if ! [[ "$MOODLE_CRON_MINUTES" =~ ^[0-9]+$ ]] || [ "$MOODLE_CRON_MINUTES" -lt 1 ]; then
        warn "Invalid MOODLE_CRON_MINUTES value: $MOODLE_CRON_MINUTES. Using default: 1 minute"
        MOODLE_CRON_MINUTES=1
    fi
    
    # Convert MOODLE_CRON_MINUTES to seconds for --keep-alive parameter
    local cron_seconds=$((MOODLE_CRON_MINUTES * 60))
    info "Starting Moodle cron with ${MOODLE_CRON_MINUTES} minute interval (${cron_seconds} seconds)"
    
    nohup /usr/bin/php /var/www/html/admin/cli/cron.php --keep-alive=${cron_seconds} > /tmp/moodle-cron.log 2>&1 &
    echo $! > /tmp/moodle-cron.pid
    info "Moodle cron process started (PID: $!)"
}

# Function to monitor cron continuously
monitor_cron() {
    while true; do
        sleep 30 # Check every 30 seconds
        
        if [ -f /tmp/moodle-cron.pid ]; then
            CRON_PID=$(cat /tmp/moodle-cron.pid)
            if ! kill -0 $CRON_PID 2>/dev/null; then
                warn "Moodle cron process died, restarting..."
                start_cron
            fi
        else
            warn "Moodle cron PID file missing, starting cron..."
            start_cron
        fi
    done
}

# Start initial cron
start_cron

# Start cron monitor in background
monitor_cron &

info "** Starting PHP-FPM **"
php-fpm${PHP_VERSION} -F & # Chạy PHP-FPM ở background

info "** Starting Apache **"
exec apache2 -DFOREGROUND # Chạy Apache ở foreground (tiến trình chính)
