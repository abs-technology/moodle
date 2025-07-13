#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh
. /scripts/lib/config.sh
. /scripts/lib/filesystem.sh
. /scripts/lib/php.sh

# Load centralized configuration
load_config

info "Starting PHP setup for Absi Technology..."

ensure_user_exists "$WEB_SERVER_DAEMON_USER" "$WEB_SERVER_DAEMON_GROUP"

ensure_dir_exists "/var/run/php" "$WEB_SERVER_DAEMON_USER" "$WEB_SERVER_DAEMON_GROUP" "775"

# Update PHP-FPM pool config to use correct PHP version socket (using centralized config)
info "Configuring PHP-FPM pool for version ${PHP_VERSION}..."
php_conf_set "listen" "$PHP_FPM_SOCKET" "$PHP_FPM_WWW_CONF"
php_conf_set "listen.owner" "$WEB_SERVER_DAEMON_USER" "$PHP_FPM_WWW_CONF"
php_conf_set "listen.group" "$WEB_SERVER_DAEMON_GROUP" "$PHP_FPM_WWW_CONF"
php_conf_set "listen.mode" "0660" "$PHP_FPM_WWW_CONF"
php_conf_set "user" "$WEB_SERVER_DAEMON_USER" "$PHP_FPM_WWW_CONF"
php_conf_set "group" "$WEB_SERVER_DAEMON_GROUP" "$PHP_FPM_WWW_CONF"
php_conf_set "chdir" "$MOODLE_DIR" "$PHP_FPM_WWW_CONF"


php_conf_set "memory_limit" "$PHP_MEMORY_LIMIT" "$PHP_INI_PATH"
php_conf_set "max_input_vars" "$PHP_MAX_INPUT_VARS" "$PHP_INI_PATH"
php_conf_set "post_max_size" "$PHP_POST_MAX_SIZE" "$PHP_INI_PATH"
php_conf_set "upload_max_filesize" "$PHP_UPLOAD_MAX_FILESIZE" "$PHP_INI_PATH"
php_conf_set "max_execution_time" "$PHP_MAX_EXECUTION_TIME" "$PHP_INI_PATH"
php_conf_set "max_file_uploads" "$PHP_MAX_FILE_UPLOADS" "$PHP_INI_PATH"
php_conf_set "expose_php" "Off" "$PHP_INI_PATH"
php_conf_set "date.timezone" "Asia/Ho_Chi_Minh" "$PHP_INI_PATH"

# Update session save path to use dynamic Moodle data directory
sed -i "s|/var/www/moodledata|$MOODLE_DATA_DIR|g" "$PHP_INI_PATH"

info "PHP setup finished."
