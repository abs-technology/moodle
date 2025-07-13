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
info "** Monitoring Moodle cron keep-alive process **"
# Check if cron process is running
if [ -f /tmp/moodle-cron.pid ]; then
    CRON_PID=$(cat /tmp/moodle-cron.pid)
    if kill -0 $CRON_PID 2>/dev/null; then
        info "Moodle cron process is running (PID: $CRON_PID)"
    else
        warn "Moodle cron process not found, restarting..."
        nohup /usr/bin/php /var/www/html/admin/cli/cron.php --keep-alive=60 > /tmp/moodle-cron.log 2>&1 &
        echo $! > /tmp/moodle-cron.pid
        info "Moodle cron process restarted (PID: $!)"
    fi
else
    warn "Moodle cron PID file not found, starting cron process..."
    nohup /usr/bin/php /var/www/html/admin/cli/cron.php --keep-alive=60 > /tmp/moodle-cron.log 2>&1 &
    echo $! > /tmp/moodle-cron.pid
    info "Moodle cron process started (PID: $!)"
fi

info "** Starting PHP-FPM **"
php-fpm${PHP_VERSION} -F & # Chạy PHP-FPM ở background

info "** Starting Apache **"
exec apache2 -DFOREGROUND # Chạy Apache ở foreground (tiến trình chính)
