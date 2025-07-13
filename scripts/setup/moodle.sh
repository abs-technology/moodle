#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh
. /scripts/lib/config.sh
. /scripts/lib/filesystem.sh
. /scripts/lib/validations.sh
. /scripts/lib/mariadb.sh
. /scripts/lib/php.sh

# Load centralized configuration
load_config

MOODLE_CONF_FILE="${MOODLE_DIR}/config.php"

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
    chown -R "${APP_USER}:${APP_GROUP}" "$MOODLE_DIR" "$MOODLE_DATA_DIR"
    chmod -R 775 "$MOODLE_DATA_DIR"
    info "Running Moodle database upgrade..."
    php "${MOODLE_DIR}/admin/cli/upgrade.php" --non-interactive --allow-unstable >/dev/null || true
    find "${MOODLE_DATA_DIR}/sessions/" -name "sess_*" -delete || true
else
    info "Initializing Moodle for the first time."
    
    ensure_dir_exists "$MOODLE_DATA_DIR" "$APP_USER" "$APP_GROUP" "775"
    ensure_dir_exists "$MOODLE_DIR" "$APP_USER" "$APP_GROUP" "755"

    # Chờ database sẵn sàng với database name cụ thể
    wait_for_db_connection "$MOODLE_DATABASE_HOST" "$MOODLE_DATABASE_PORT_NUMBER" "$MOODLE_DATABASE_USER" "$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME"

    info "Running Moodle CLI installation..."
    php "${MOODLE_DIR}/admin/cli/install.php" \
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

# Cron job configured in entrypoint.sh for non-root user compatibility
info "Cron job configured during container startup..."

# Restart cron để nhận user crontab mới
if pgrep cron > /dev/null; then
    info "Restarting cron daemon to pick up user crontab..."
    pkill -HUP cron || true
fi

# Luôn cập nhật wwwroot mỗi khi container start
info "Configuring Moodle wwwroot..."

# Sử dụng PHP để cập nhật wwwroot động
if [[ -f "$MOODLE_CONF_FILE" ]]; then
    # Tạo file PHP tạm để tránh bash expansion conflicts
    cat > /tmp/update_wwwroot.php << 'EOF'
<?php
define('CLI_SCRIPT', true);

$config_file = $argv[1];
require_once($config_file);

$config_content = file_get_contents($config_file);

// Thay thế wwwroot bằng dynamic detection
$dynamic_wwwroot = '
// Dynamic wwwroot detection
if (!empty($_SERVER["HTTP_HOST"])) {
    $protocol = (!empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off") ? "https" : "http";
    $CFG->wwwroot = $protocol . "://" . $_SERVER["HTTP_HOST"];
} else {
    $CFG->wwwroot = "http://localhost";
}';

$config_content = preg_replace(
    '/^\$CFG->wwwroot\s*=\s*[^;]+;/m',
    $dynamic_wwwroot,
    $config_content
);

file_put_contents($config_file, $config_content);
echo "Moodle wwwroot updated to dynamic detection.\n";
EOF

    # Chạy PHP script với quyền user
    php /tmp/update_wwwroot.php "$MOODLE_DIR/config.php"
    rm -f /tmp/update_wwwroot.php
fi

info "Moodle application setup finished."
