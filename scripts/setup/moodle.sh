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

# Function to check and wait for DB
wait_for_db_connection() {
    local db_host="$1"
    local db_port="$2"
    local db_user="$3"
    local db_pass="$4"
    local db_name="$5"
    info "Waiting for database connection at ${db_host}:${db_port}..."
    
    # Check connection to specific database
    check_mariadb_connection() {
        echo "SELECT 1" | mariadb_remote_execute "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass"
    }
    
    if ! retry_while "check_mariadb_connection" 60 5; then
        error "Could not connect to the database server!"
        exit 1
    fi
    info "Database connection successful!"
}

# Main logic of Moodle Setup  
if [[ -f "$MOODLE_CONF_FILE" ]]; then
    info "Moodle already initialized. Skipping fresh installation."
    
    # Ensure Moodle source is available even if already initialized
    if [[ ! -f "$MOODLE_DIR/lib/setup.php" && -d "$MOODLE_SOURCE_DIR" ]]; then
        info "Moodle source missing, copying from backup..."
        cp -r "$MOODLE_SOURCE_DIR"/* "$MOODLE_DIR"/
        chown -R "${APP_USER}:${APP_GROUP}" "$MOODLE_DIR"
    fi
    
    chown -R "${APP_USER}:${APP_GROUP}" "$MOODLE_DIR" "$MOODLE_DATA_DIR"
    chmod -R 775 "$MOODLE_DATA_DIR"
    
    # Add security settings to config.php
    if ! grep -q "preventexecpath" "$MOODLE_CONF_FILE"; then
        # Temporarily make writable to add security setting
        chmod 644 "$MOODLE_CONF_FILE"
        # Insert before the final require_once line
        sed -i '/require_once.*lib\/setup\.php/i $CFG->preventexecpath = true;' "$MOODLE_CONF_FILE"
        debug "Added preventexecpath = true to config.php for security"
    fi
    
    # Set config.php to read-only for security
    chmod 644 "$MOODLE_CONF_FILE"
    debug "Set config.php to read-only (644) for security"
    
    info "Running Moodle database upgrade..."
    php "${MOODLE_DIR}/admin/cli/upgrade.php" --non-interactive --allow-unstable >/dev/null || true
    find "${MOODLE_DATA_DIR}/sessions/" -name "sess_*" -delete || true
else
    info "Initializing Moodle for the first time."
    
    ensure_dir_exists "$MOODLE_DATA_DIR" "$APP_USER" "$APP_GROUP" "775"
    ensure_dir_exists "$MOODLE_DIR" "$APP_USER" "$APP_GROUP" "755"

    # Wait for database to be ready with specific database name
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
    
    # Add security settings to config.php
    if [[ -f "$MOODLE_CONF_FILE" ]]; then
        # Add preventexecpath setting for security
        if ! grep -q "preventexecpath" "$MOODLE_CONF_FILE"; then
            # Insert before the final require_once line
            sed -i '/require_once.*lib\/setup\.php/i $CFG->preventexecpath = true;' "$MOODLE_CONF_FILE"
            info "Added preventexecpath = true to config.php for security"
        fi
        
        # Set config.php to read-only for security
        chmod 644 "$MOODLE_CONF_FILE"
        info "Set config.php to read-only (644) for security"
    fi
    
    info "Moodle initial installation completed."
fi

# Cron job configured in entrypoint.sh for non-root user compatibility
info "Cron job configured during container startup..."

# Restart cron to pick up new user crontab
if pgrep cron > /dev/null; then
    info "Restarting cron daemon to pick up user crontab..."
    pkill -HUP cron || true
fi

# Always update wwwroot each time container starts
info "Configuring Moodle wwwroot..."

# Configure Moodle based on load balancing settings (Option B logic with templates)
if [[ -f "$MOODLE_CONF_FILE" ]]; then
    info "Configuring Moodle for proxy settings..."
    debug "MOODLE_REVERSEPROXY: ${MOODLE_REVERSEPROXY}"
    debug "MOODLE_SSLPROXY: ${MOODLE_SSLPROXY}"
    debug "MOODLE_DOMAIN: ${MOODLE_DOMAIN:-}"
    
    # Configure based on proxy mode using simple approach
    if [[ "$MOODLE_REVERSEPROXY" == "yes" ]]; then
        info "Load balancer mode - updating Moodle config for proxy"
        REVERSEPROXY_SETTING="true"
        if [[ "$MOODLE_SSLPROXY" == "yes" ]]; then
            SSLPROXY_SETTING="true"
        else
            SSLPROXY_SETTING="false"
        fi
        
        if [[ -n "${MOODLE_DOMAIN:-}" ]]; then
            # Fixed domain for load balancer
            WWWROOT_CONFIG='
// Fixed domain configuration for load balancer
$protocol = "http";
if (!empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off") {
    $protocol = "https";
} elseif (!empty($_SERVER["HTTP_X_FORWARDED_PROTO"]) && $_SERVER["HTTP_X_FORWARDED_PROTO"] === "https") {
    $protocol = "https";
}
$CFG->wwwroot = $protocol . "://'${MOODLE_DOMAIN}'";'
        else
            # Dynamic domain for load balancer  
            WWWROOT_CONFIG='
// Dynamic wwwroot detection with load balancer support
if (!empty($_SERVER["HTTP_HOST"])) {
    $protocol = "http";
    if (!empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off") {
        $protocol = "https";
    } elseif (!empty($_SERVER["HTTP_X_FORWARDED_PROTO"]) && $_SERVER["HTTP_X_FORWARDED_PROTO"] === "https") {
        $protocol = "https";
    }
    $CFG->wwwroot = $protocol . "://" . $_SERVER["HTTP_HOST"];
} else {
    $CFG->wwwroot = "http://localhost";
}'
        fi
        
        PROXY_CONFIG="

// Load balancer configuration
\$CFG->reverseproxy = ${REVERSEPROXY_SETTING};
\$CFG->sslproxy = ${SSLPROXY_SETTING};

// Session clustering for load balancing
\$CFG->session_handler_class = '\\core\\session\\file';
\$CFG->session_file_save_path = '/var/www/moodledata/sessions';"
        
    else
        info "Direct connection mode - updating Moodle config for direct access"
        
        if [[ -n "${MOODLE_DOMAIN:-}" ]]; then
            # Fixed domain for direct connection
            WWWROOT_CONFIG='
// Fixed domain configuration for direct connection
$protocol = (!empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off") ? "https" : "http";
$CFG->wwwroot = $protocol . "://'${MOODLE_DOMAIN}'";'
        else
            # Dynamic domain for direct connection
            WWWROOT_CONFIG='
// Dynamic wwwroot detection - direct connection only
if (!empty($_SERVER["HTTP_HOST"])) {
    $protocol = (!empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off") ? "https" : "http";
    $CFG->wwwroot = $protocol . "://" . $_SERVER["HTTP_HOST"];
} else {
    $CFG->wwwroot = "http://localhost";
}'
        fi
        
        PROXY_CONFIG="

// Direct connection mode - no load balancer
// \$CFG->reverseproxy = false; // Default
// \$CFG->sslproxy = false; // Default
// Default session handling - no shared storage needed"
    fi
    
    # Create simple PHP script to update config
    cat > /tmp/update_moodle_config.php << 'PHPEOF'
<?php
$config_file = $argv[1];
$config_content = file_get_contents($config_file);

// Remove old configurations if any
$config_content = preg_replace('/\/\/ (Load balancer|Direct connection|Fixed domain|Dynamic wwwroot).*?(\$CFG->session_file_save_path.*?;|\/\/ Default session handling.*?\n)/s', '', $config_content);

// Insert new configuration before preventexecpath
$new_config = $argv[2] . $argv[3];
$config_content = preg_replace('/(\$CFG->preventexecpath = true;)/', $new_config . "\n\n$1", $config_content);

file_put_contents($config_file, $config_content);
echo "Moodle configuration updated successfully\n";
PHPEOF

    # Run PHP script with wwwroot and proxy configs
    php /tmp/update_moodle_config.php "$MOODLE_DIR/config.php" "$WWWROOT_CONFIG" "$PROXY_CONFIG"
    rm -f /tmp/update_moodle_config.php
fi

info "Moodle application setup finished."
