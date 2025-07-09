#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh
. /scripts/lib/filesystem.sh
. /scripts/lib/validations.sh
. /scripts/lib/mariadb.sh
. /scripts/lib/php.sh

MOODLE_DIR="/var/www/html"
MOODLE_DATA_DIR="${MOODLE_DATA_DIR:-/var/www/moodledata}"
MOODLE_CONF_FILE="${MOODLE_DIR}/config.php"

# Biến môi trường Moodle
MOODLE_DATABASE_TYPE="${MOODLE_DATABASE_TYPE:-mariadb}"
MOODLE_DATABASE_HOST="${MOODLE_DATABASE_HOST:-mariadb}"
MOODLE_DATABASE_PORT_NUMBER="${MOODLE_DATABASE_PORT_NUMBER:-3306}"
MOODLE_DATABASE_NAME="${MOODLE_DATABASE_NAME:-absi_moodle_db}"
MOODLE_DATABASE_USER="${MOODLE_DATABASE_USER:-absi_moodle_user}"
MOODLE_DATABASE_PASSWORD="${MOODLE_DATABASE_PASSWORD:-password}"
MOODLE_USERNAME="${MOODLE_USERNAME:-absi_admin}"
MOODLE_PASSWORD="${MOODLE_PASSWORD:-password}"
MOODLE_EMAIL="${MOODLE_EMAIL:-henry@absi.edu.vn}"
MOODLE_SITE_NAME="${MOODLE_SITE_NAME:-Absi Technology Moodle LMS}"
MOODLE_CRON_MINUTES="${MOODLE_CRON_MINUTES:-1}"
MOODLE_HOST="${MOODLE_HOST:-localhost}"
MOODLE_REVERSEPROXY="${MOODLE_REVERSEPROXY:-no}"
MOODLE_SSLPROXY="${MOODLE_SSLPROXY:-no}"

# Người dùng hệ thống của ứng dụng
APP_USER="absiuser"
APP_GROUP="absiuser"

# Hàm kiểm tra và chờ DB
wait_for_db_connection() {
    local db_host="$1"
    local db_port="$2"
    local db_user="$3"
    local db_pass="$4"
    local db_name="$5"
    info "Waiting for database connection at ${db_host}:${db_port}..."
    
    # Kiểm tra kết nối với database cụ thể
    check_mariadb_connection() {
        echo "SELECT 1" | mariadb_remote_execute "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass"
    }
    
    if ! retry_while "check_mariadb_connection" 60 5; then
        error "Could not connect to the database server!"
        exit 1
    fi
    info "Database connection successful!"
}

# Logic chính của Moodle Setup  
if [[ -f "$MOODLE_CONF_FILE" ]]; then
    info "Moodle already initialized. Skipping fresh installation."
    chown -R "${APP_USER}:${APP_GROUP}" /var/www/html /var/www/moodledata
    chmod -R 775 /var/www/moodledata
    info "Running Moodle database upgrade..."
    run_as_user "$APP_USER" php "${MOODLE_DIR}/admin/cli/upgrade.php" --non-interactive --allow-unstable >/dev/null || true
    find "${MOODLE_DATA_DIR}/sessions/" -name "sess_*" -delete || true
else
    info "Initializing Moodle for the first time."
    
    ensure_dir_exists "$MOODLE_DATA_DIR" "$APP_USER" "$APP_GROUP" "775"
    ensure_dir_exists "/var/www/html" "$APP_USER" "$APP_GROUP" "755"

    # Chờ database sẵn sàng với database name cụ thể
    wait_for_db_connection "$MOODLE_DATABASE_HOST" "$MOODLE_DATABASE_PORT_NUMBER" "$MOODLE_DATABASE_USER" "$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME"

    info "Running Moodle CLI installation..."
    run_as_user "$APP_USER" php "${MOODLE_DIR}/admin/cli/install.php" \
        --lang=en \
        --chmod=2775 \
        --wwwroot="http://${MOODLE_HOST}" \
        --dataroot="${MOODLE_DATA_DIR}" \
        --adminuser="${MOODLE_USERNAME}" \
        --adminpass="${MOODLE_PASSWORD}" \
        --adminemail="${MOODLE_EMAIL}" \
        --fullname="${MOODLE_SITE_NAME}" \
        --shortname="${MOODLE_SITE_NAME}" \
        --dbtype="${MOODLE_DATABASE_TYPE}" \
        --dbhost="${MOODLE_DATABASE_HOST}" \
        --dbport="${MOODLE_DATABASE_PORT_NUMBER}" \
        --dbname="${MOODLE_DATABASE_NAME}" \
        --dbuser="${MOODLE_DATABASE_USER}" \
        --dbpass="${MOODLE_DATABASE_PASSWORD}" \
        --non-interactive \
        --allow-unstable \
        --agree-license >/dev/null

    touch "$MOODLE_DATA_DIR/.moodle_initialized"
    info "Moodle initial installation completed."
fi

# Cấu hình cron job
info "Configuring Moodle cron job..."
cat > /etc/cron.d/moodle <<EOF
# Moodle cron job - runs every ${MOODLE_CRON_MINUTES} minute(s)
*/${MOODLE_CRON_MINUTES} * * * * ${APP_USER} php /var/www/html/admin/cli/cron.php > /dev/null 2>&1

EOF
chmod 0644 /etc/cron.d/moodle

# Restart cron để nhận file mới (nếu cron đang chạy)
if pgrep cron > /dev/null; then
    info "Restarting cron daemon to pick up new configuration..."
    pkill -HUP cron || true
fi

# Luôn cập nhật wwwroot mỗi khi container start
info "Configuring Moodle wwwroot..."

# Tạo file PHP để xử lý cấu hình
cat > /tmp/configure_moodle.php << 'PHP_SCRIPT_END'
<?php
define('CLI_SCRIPT', true);
require_once('/var/www/html/config.php');

// Hàm cập nhật cấu hình
function update_config($config_file) {
    global $CFG;
    
    // Cập nhật các cài đặt khác
    $CFG->reverseproxy = (getenv('MOODLE_REVERSEPROXY') === 'yes');
    $CFG->sslproxy = (getenv('MOODLE_SSLPROXY') === 'yes');
    
    // Đọc file cấu hình
    $config_content = file_get_contents($config_file);
    
    // Thay thế wwwroot cố định bằng dynamic detection
    $dynamic_wwwroot = "
// Dynamic wwwroot detection
if (!empty(\$_SERVER['HTTP_HOST'])) {
    \$protocol = (!empty(\$_SERVER['HTTPS']) && \$_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    \$CFG->wwwroot = \$protocol . '://' . \$_SERVER['HTTP_HOST'];
} else {
    \$CFG->wwwroot = 'http://localhost';
}";
    
    // Thay thế dòng wwwroot cũ
    $config_content = preg_replace(
        '/^\$CFG->wwwroot\s*=\s*[^;]+;/m',
        $dynamic_wwwroot,
        $config_content
    );
    
    // Cập nhật reverseproxy
    $config_content = preg_replace(
        '/^\$CFG->reverseproxy\s*=\s*[^;]+;/m',
        '$CFG->reverseproxy = ' . (($CFG->reverseproxy) ? 'true' : 'false') . ';',
        $config_content
    );
    
    // Cập nhật sslproxy
    $config_content = preg_replace(
        '/^\$CFG->sslproxy\s*=\s*[^;]+;/m',
        '$CFG->sslproxy = ' . (($CFG->sslproxy) ? 'true' : 'false') . ';',
        $config_content
    );
    
    // Ghi lại file cấu hình
    file_put_contents($config_file, $config_content);
    
    echo "Moodle configuration updated with dynamic wwwroot detection:\n";
    echo "- reverseproxy: " . ($CFG->reverseproxy ? 'true' : 'false') . "\n";
    echo "- sslproxy: " . ($CFG->sslproxy ? 'true' : 'false') . "\n";
}

// Thực thi cập nhật
update_config('/var/www/html/config.php');
PHP_SCRIPT_END

# Thực thi file PHP
run_as_user "$APP_USER" php /tmp/configure_moodle.php
rm -f /tmp/configure_moodle.php

info "Moodle application setup finished."
