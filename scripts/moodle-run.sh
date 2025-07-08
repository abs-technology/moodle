#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh
. /scripts/lib/service.sh

# Định nghĩa các biến môi trường và đường dẫn cần thiết cho runtime
PHP_VERSION="${PHP_VERSION:-8.2}"

# Hàm xử lý tín hiệu TERM để dừng các tiến trình con
_forwardTerm() {
    warn "Caught signal SIGTERM, passing it to child processes..."
    kill "$(jobs -p)" # Dừng các tiến trình con đã chạy trong background
    wait # Chờ tất cả các tiến trình con kết thúc
    exit $?
}
trap _forwardTerm TERM

info "** Starting cron **"
cron -f & # Chạy cron ở background

info "** Starting PHP-FPM **"
php-fpm${PHP_VERSION} -F & # Chạy PHP-FPM ở background

info "** Starting Apache **"
exec apache2 -DFOREGROUND # Chạy Apache ở foreground (tiến trình chính)
