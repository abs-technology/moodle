#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh
. /scripts/lib/filesystem.sh
. /scripts/lib/php.sh

PHP_FPM_DAEMON_USER="absiuser"
PHP_FPM_DAEMON_GROUP="absiuser"
PHP_VERSION="${PHP_VERSION:-8.2}"
PHP_INI_PATH="/etc/php/${PHP_VERSION}/fpm/php.ini"
PHP_FPM_WWW_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"

PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-256M}"
PHP_MAX_INPUT_VARS="${PHP_MAX_INPUT_VARS:-5000}"
PHP_POST_MAX_SIZE="${PHP_POST_MAX_SIZE:-50M}"
PHP_UPLOAD_MAX_FILESIZE="${PHP_UPLOAD_MAX_FILESIZE:-40M}"
PHP_MAX_EXECUTION_TIME="${PHP_MAX_EXECUTION_TIME:-300}"
PHP_MAX_FILE_UPLOADS="${PHP_MAX_FILE_UPLOADS:-20}"

info "Starting PHP setup for Absi Technology..."

ensure_user_exists "$PHP_FPM_DAEMON_USER" "$PHP_FPM_DAEMON_GROUP"

ensure_dir_exists "/var/run/php" "$PHP_FPM_DAEMON_USER" "$PHP_FPM_DAEMON_GROUP" "775"

php_conf_set "listen" "/var/run/php/php${PHP_VERSION}-fpm.sock" "$PHP_FPM_WWW_CONF"
php_conf_set "listen.owner" "$PHP_FPM_DAEMON_USER" "$PHP_FPM_WWW_CONF"
php_conf_set "listen.group" "$PHP_FPM_DAEMON_GROUP" "$PHP_FPM_WWW_CONF"
php_conf_set "listen.mode" "0660" "$PHP_FPM_WWW_CONF"
php_conf_set "user" "$PHP_FPM_DAEMON_USER" "$PHP_FPM_WWW_CONF"
php_conf_set "group" "$PHP_FPM_DAEMON_GROUP" "$PHP_FPM_WWW_CONF"


php_conf_set "memory_limit" "$PHP_MEMORY_LIMIT" "$PHP_INI_PATH"
php_conf_set "max_input_vars" "$PHP_MAX_INPUT_VARS" "$PHP_INI_PATH"
php_conf_set "post_max_size" "$PHP_POST_MAX_SIZE" "$PHP_INI_PATH"
php_conf_set "upload_max_filesize" "$PHP_UPLOAD_MAX_FILESIZE" "$PHP_INI_PATH"
php_conf_set "max_execution_time" "$PHP_MAX_EXECUTION_TIME" "$PHP_INI_PATH"
php_conf_set "max_file_uploads" "$PHP_MAX_FILE_UPLOADS" "$PHP_INI_PATH"
php_conf_set "expose_php" "Off" "$PHP_INI_PATH"
php_conf_set "date.timezone" "Asia/Ho_Chi_Minh" "$PHP_INI_PATH"

info "PHP setup finished."
