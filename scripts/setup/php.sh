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

# Function to update PHP INI file with templates
update_php_ini() {
    local ini_file="$1"
    local ini_type="$2"
    
    if [[ -f "$ini_file" ]]; then
        debug "Replacing template placeholders in $ini_type PHP INI: $ini_file"
        sed -i "s|{{PHP_OUTPUT_BUFFERING}}|${PHP_OUTPUT_BUFFERING}|g" "$ini_file"
        sed -i "s|{{PHP_MAX_EXECUTION_TIME}}|${PHP_MAX_EXECUTION_TIME}|g" "$ini_file"
        sed -i "s|{{PHP_MAX_INPUT_TIME}}|${PHP_MAX_INPUT_TIME}|g" "$ini_file"
        sed -i "s|{{PHP_MEMORY_LIMIT}}|${PHP_MEMORY_LIMIT}|g" "$ini_file"
        # PHP_ERROR_REPORTING is hardcoded in php.ini due to special characters
        # TODO: Could be improved with environment variable if needed
        sed -i "s|{{PHP_DISPLAY_ERRORS}}|${PHP_DISPLAY_ERRORS}|g" "$ini_file"
        sed -i "s|{{PHP_LOG_ERRORS}}|${PHP_LOG_ERRORS}|g" "$ini_file"
        sed -i "s|{{PHP_POST_MAX_SIZE}}|${PHP_POST_MAX_SIZE}|g" "$ini_file"
        sed -i "s|{{PHP_UPLOAD_MAX_FILESIZE}}|${PHP_UPLOAD_MAX_FILESIZE}|g" "$ini_file"
        sed -i "s|{{PHP_MAX_FILE_UPLOADS}}|${PHP_MAX_FILE_UPLOADS}|g" "$ini_file"
        sed -i "s|{{PHP_DEFAULT_SOCKET_TIMEOUT}}|${PHP_DEFAULT_SOCKET_TIMEOUT}|g" "$ini_file"
        sed -i "s|{{PHP_MAX_INPUT_VARS}}|${PHP_MAX_INPUT_VARS}|g" "$ini_file"
        sed -i "s|{{MOODLE_DATA_DIR}}|${MOODLE_DATA_DIR}|g" "$ini_file"
        sed -i "s|{{SYSTEM_TIMEZONE}}|${SYSTEM_TIMEZONE}|g" "$ini_file"
    else
        warn "$ini_type PHP INI file not found: $ini_file"
    fi
}

# Replace template placeholders in both PHP INI files
info "Updating PHP INI files with environment variables..."
update_php_ini "$PHP_INI_PATH" "FPM"
update_php_ini "$PHP_CLI_INI_PATH" "CLI"

# Replace template placeholders in PHP-FPM pool config
info "Updating PHP-FPM pool configuration with environment variables..."
if [[ -f "$PHP_FPM_WWW_CONF" ]]; then
    debug "Replacing template placeholders in PHP-FPM pool config..."
    sed -i "s|{{APP_USER}}|${APP_USER}|g" "$PHP_FPM_WWW_CONF"
    sed -i "s|{{APP_GROUP}}|${APP_GROUP}|g" "$PHP_FPM_WWW_CONF"
    sed -i "s|{{MOODLE_DIR}}|${MOODLE_DIR}|g" "$PHP_FPM_WWW_CONF"
    sed -i "s|{{PHP_FPM_PM}}|${PHP_FPM_PM}|g" "$PHP_FPM_WWW_CONF"
    sed -i "s|{{PHP_FPM_MAX_CHILDREN}}|${PHP_FPM_MAX_CHILDREN}|g" "$PHP_FPM_WWW_CONF"
    sed -i "s|{{PHP_FPM_START_SERVERS}}|${PHP_FPM_START_SERVERS}|g" "$PHP_FPM_WWW_CONF"
    sed -i "s|{{PHP_FPM_MIN_SPARE_SERVERS}}|${PHP_FPM_MIN_SPARE_SERVERS}|g" "$PHP_FPM_WWW_CONF"
    sed -i "s|{{PHP_FPM_MAX_SPARE_SERVERS}}|${PHP_FPM_MAX_SPARE_SERVERS}|g" "$PHP_FPM_WWW_CONF"
    sed -i "s|{{PHP_FPM_MAX_REQUESTS}}|${PHP_FPM_MAX_REQUESTS}|g" "$PHP_FPM_WWW_CONF"
fi

# Update PHP-FPM pool config to use correct PHP version socket (using centralized config)
info "Configuring PHP-FPM pool for version ${PHP_VERSION}..."
php_conf_set "listen" "$PHP_FPM_SOCKET" "$PHP_FPM_WWW_CONF"
php_conf_set "listen.owner" "$WEB_SERVER_DAEMON_USER" "$PHP_FPM_WWW_CONF"
php_conf_set "listen.group" "$WEB_SERVER_DAEMON_GROUP" "$PHP_FPM_WWW_CONF"
php_conf_set "listen.mode" "0660" "$PHP_FPM_WWW_CONF"
php_conf_set "user" "$WEB_SERVER_DAEMON_USER" "$PHP_FPM_WWW_CONF"
php_conf_set "group" "$WEB_SERVER_DAEMON_GROUP" "$PHP_FPM_WWW_CONF"
php_conf_set "chdir" "$MOODLE_DIR" "$PHP_FPM_WWW_CONF"

# Apply additional PHP settings to both FPM and CLI (these override template values if needed)
info "Applying additional PHP configuration..."

# Function to apply settings to both INI files
apply_php_setting() {
    local key="$1"
    local value="$2"
    php_conf_set "$key" "$value" "$PHP_INI_PATH"
    [[ -f "$PHP_CLI_INI_PATH" ]] && php_conf_set "$key" "$value" "$PHP_CLI_INI_PATH"
}

apply_php_setting "memory_limit" "$PHP_MEMORY_LIMIT"
apply_php_setting "max_input_vars" "$PHP_MAX_INPUT_VARS"
apply_php_setting "post_max_size" "$PHP_POST_MAX_SIZE"
apply_php_setting "upload_max_filesize" "$PHP_UPLOAD_MAX_FILESIZE"
apply_php_setting "max_execution_time" "$PHP_MAX_EXECUTION_TIME"
apply_php_setting "max_file_uploads" "$PHP_MAX_FILE_UPLOADS"
apply_php_setting "expose_php" "Off"
apply_php_setting "date.timezone" "$SYSTEM_TIMEZONE"

# Update session save path to use dynamic Moodle data directory (for compatibility)
[[ -f "$PHP_INI_PATH" ]] && sed -i "s|/var/www/moodledata|$MOODLE_DATA_DIR|g" "$PHP_INI_PATH"
[[ -f "$PHP_CLI_INI_PATH" ]] && sed -i "s|/var/www/moodledata|$MOODLE_DATA_DIR|g" "$PHP_CLI_INI_PATH"

# Configure PHP session path based on load balancing settings
info "Configuring PHP session storage for proxy mode..."
debug "MOODLE_REVERSEPROXY: ${MOODLE_REVERSEPROXY}"

if [[ "$MOODLE_REVERSEPROXY" == "yes" ]]; then
    info "Load balancer mode - using shared session storage"
    SESSION_SAVE_PATH="${MOODLE_DATA_DIR}/sessions"
    
    # Ensure shared session directory exists
    mkdir -p "$SESSION_SAVE_PATH"
    chown -R "$APP_USER:$APP_GROUP" "$SESSION_SAVE_PATH"
    chmod 755 "$SESSION_SAVE_PATH"
    
    # Update PHP-FPM pool config for shared sessions
    if [[ -f "$PHP_FPM_WWW_CONF" ]]; then
        sed -i "s|php_value\[session.save_path\] = .*|php_value[session.save_path] = \"$SESSION_SAVE_PATH\"|g" "$PHP_FPM_WWW_CONF"
        debug "Updated PHP-FPM session path to: $SESSION_SAVE_PATH"
    fi
else
    info "Direct connection mode - using local session storage"
    SESSION_SAVE_PATH="${MOODLE_DATA_DIR}/local_sessions"
    
    # Ensure local session directory exists (use moodledata to avoid permission issues)
    mkdir -p "$SESSION_SAVE_PATH"
    chown -R "$APP_USER:$APP_GROUP" "$SESSION_SAVE_PATH"
    chmod 755 "$SESSION_SAVE_PATH"
    
    # Update PHP-FPM pool config for local sessions
    if [[ -f "$PHP_FPM_WWW_CONF" ]]; then
        sed -i "s|php_value\[session.save_path\] = .*|php_value[session.save_path] = \"$SESSION_SAVE_PATH\"|g" "$PHP_FPM_WWW_CONF"
        debug "Updated PHP-FPM session path to: $SESSION_SAVE_PATH"
    fi
fi

info "PHP setup finished."
