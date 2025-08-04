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

# ============================================================================
# FUNCTION DEFINITIONS
# ============================================================================

# Apply environment variable overrides to config.php and database
apply_environment_overrides() {
    # Check if environment overrides have already been applied (stability marker)
    local env_applied_marker="$MOODLE_DATA_DIR/.absi_env_applied"
    
    if [[ -f "$env_applied_marker" ]]; then
        info "Environment variables already applied on first run. Preserving system stability."
        debug "Skipping environment overrides to maintain stable configuration"
        return 0
    fi
    
    info "First run detected. Applying environment variable overrides to Moodle configuration..."
    
    # Only apply if config.php exists (pre-built installation)
    if [[ -f "$MOODLE_CONF_FILE" ]]; then
        apply_config_php_overrides
        apply_database_overrides
        
        # Mark environment variables as applied to prevent future overwrites
        touch "$env_applied_marker"
        chown "$APP_USER:$APP_GROUP" "$env_applied_marker"
        info "Environment variables applied successfully. Future restarts will preserve these settings."
    else
        debug "No config.php found, skipping environment overrides"
    fi
}

# Update config.php with environment variables
apply_config_php_overrides() {
    info "Updating config.php with environment variables..."
    
    # Create temporary PHP script to update config.php safely
    cat > /tmp/update_config.php << 'EOF'
<?php
$config_file = $argv[1];
$config_content = file_get_contents($config_file);

// Update database connection settings
$config_content = preg_replace(
    '/\$CFG->dbtype\s*=\s*[^;]+;/',
    '$CFG->dbtype    = \'' . getenv('MOODLE_DATABASE_TYPE') . '\';',
    $config_content
);

$config_content = preg_replace(
    '/\$CFG->dbhost\s*=\s*[^;]+;/',
    '$CFG->dbhost    = \'' . getenv('MOODLE_DATABASE_HOST') . '\';',
    $config_content
);

$config_content = preg_replace(
    '/\$CFG->dbname\s*=\s*[^;]+;/',
    '$CFG->dbname    = \'' . getenv('MARIADB_DATABASE') . '\';',
    $config_content
);

$config_content = preg_replace(
    '/\$CFG->dbuser\s*=\s*[^;]+;/',
    '$CFG->dbuser    = \'' . getenv('MARIADB_USER') . '\';',
    $config_content
);

$config_content = preg_replace(
    '/\$CFG->dbpass\s*=\s*[^;]+;/',
    '$CFG->dbpass    = \'' . getenv('MARIADB_PASSWORD') . '\';',
    $config_content
);

$config_content = preg_replace(
    '/\$CFG->prefix\s*=\s*[^;]+;/',
    '$CFG->prefix    = \'mdl_\';',
    $config_content
);

// Update port in dboptions if exists
$config_content = preg_replace(
    '/([\'"]dbport[\'"])\s*=>\s*[0-9]+/',
    '$1 => ' . getenv('MOODLE_DATABASE_PORT_NUMBER'),
    $config_content
);

file_put_contents($config_file, $config_content);
echo "Config.php updated successfully\n";
EOF

    php /tmp/update_config.php "$MOODLE_CONF_FILE"
    rm -f /tmp/update_config.php
    debug "Config.php updated with environment variables"
}

# Update database settings with environment variables
apply_database_overrides() {
    info "Updating database with environment variables..."
    
    # Check database connection first
    if ! echo "SELECT 1" | mariadb_remote_execute "$MOODLE_DATABASE_HOST" "$MOODLE_DATABASE_PORT_NUMBER" "$MOODLE_DATABASE_NAME" "$MOODLE_DATABASE_USER" "$MOODLE_DATABASE_PASSWORD" >/dev/null 2>&1; then
        warn "Cannot connect to database, skipping database overrides"
        return 1
    fi
    
    # Update admin user settings
    update_admin_user
    
    # Update site settings
    update_site_settings
}

# Update admin user with environment variables
update_admin_user() {
    info "Updating admin user with environment variables..."
    
    # Check if admin user exists
    local admin_exists=$(echo "SELECT COUNT(*) FROM mdl_user WHERE username = 'admin';" | \
        mariadb_remote_execute "$MOODLE_DATABASE_HOST" "$MOODLE_DATABASE_PORT_NUMBER" \
        "$MOODLE_DATABASE_NAME" "$MOODLE_DATABASE_USER" "$MOODLE_DATABASE_PASSWORD" 2>/dev/null || echo "0")
    
    if [ "$admin_exists" -gt 0 ]; then
        info "Updating existing admin user: ${MOODLE_USERNAME}"
        
        # Generate password hash (Moodle uses password_hash with PASSWORD_DEFAULT)
        local password_hash=$(php -r "echo password_hash('${MOODLE_PASSWORD}', PASSWORD_DEFAULT);")
        
        mariadb_remote_execute "$MOODLE_DATABASE_HOST" "$MOODLE_DATABASE_PORT_NUMBER" \
            "$MOODLE_DATABASE_NAME" "$MOODLE_DATABASE_USER" "$MOODLE_DATABASE_PASSWORD" <<EOF
UPDATE mdl_user SET 
    username = '${MOODLE_USERNAME}',
    password = '${password_hash}',
    email = '${MOODLE_EMAIL}',
    firstname = 'Admin',
    lastname = 'User',
    timemodified = UNIX_TIMESTAMP()
WHERE username = 'admin' OR (username = '${MOODLE_USERNAME}' AND auth = 'manual');
EOF
        debug "Admin user updated successfully"
    else
        warn "No admin user found in database to update"
    fi
}

# Update site settings with environment variables
update_site_settings() {
    info "Updating site settings with environment variables..."
    
    # Update site configuration in mdl_config table
    mariadb_remote_execute "$MOODLE_DATABASE_HOST" "$MOODLE_DATABASE_PORT_NUMBER" \
        "$MOODLE_DATABASE_NAME" "$MOODLE_DATABASE_USER" "$MOODLE_DATABASE_PASSWORD" <<EOF
-- Update or insert site settings
INSERT INTO mdl_config (name, value) VALUES 
    ('fullname', '${MOODLE_SITE_FULLNAME}'),
    ('shortname', '${MOODLE_SITE_SHORTNAME}')
ON DUPLICATE KEY UPDATE 
    value = VALUES(value);

-- Update existing site name if exists  
UPDATE mdl_config SET value = '${MOODLE_SITE_NAME}' WHERE name = 'sitename';
INSERT INTO mdl_config (name, value) SELECT 'sitename', '${MOODLE_SITE_NAME}' 
WHERE NOT EXISTS (SELECT 1 FROM mdl_config WHERE name = 'sitename');
EOF
    debug "Site settings updated successfully"
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

# First, check and copy Moodle source code if needed
if [ -d "/opt/moodle-source" ]; then
    # Check if MOODLE_DIR has complete Moodle installation
    # Check for core Moodle files to determine if this is first run
    if [ ! -f "$MOODLE_DIR/index.php" ] || [ ! -f "$MOODLE_DIR/config-dist.php" ]; then
        info "First run detected or incomplete Moodle installation. Initializing from pre-built source..."
        ensure_dir_exists "$MOODLE_DIR" "$APP_USER" "$APP_GROUP" "755"
        
        # Copy all source code (first run only)
        info "Copying pre-built source code..."
        cp -rf /opt/moodle-source/* "$MOODLE_DIR/" 2>/dev/null || true
        cp -rf /opt/moodle-source/.[!.]* "$MOODLE_DIR/" 2>/dev/null || true
        chown -R "${APP_USER}:${APP_GROUP}" "$MOODLE_DIR"
        
        # Set proper permissions for Moodle
        find "$MOODLE_DIR" -type d -exec chmod 755 {} +
        find "$MOODLE_DIR" -type f -exec chmod 644 {} +
        info "Moodle source code deployed successfully."
    else
        info "Existing Moodle installation detected. Preserving user data and customizations."
    fi
fi

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

# Hàm kiểm tra xem database đã có data chưa
check_database_has_data() {
    local db_host="$1"
    local db_port="$2"
    local db_user="$3"
    local db_pass="$4"
    local db_name="$5"
    
    # Kiểm tra xem có table mdl_config không (table cơ bản của Moodle)
    local table_count=$(echo "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$db_name' AND table_name = 'mdl_config';" | mariadb_remote_execute "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass" 2>/dev/null || echo "0")
    
    if [ "$table_count" -gt 0 ]; then
        return 0  # Database đã có data
    else
        return 1  # Database chưa có data
    fi
}

# Logic chính của Moodle Setup  
if [[ -f "$MOODLE_CONF_FILE" ]]; then
    info "Config.php found. Checking if pre-built database needs to be imported..."
    
    # Ensure directories exist
    ensure_dir_exists "$MOODLE_DATA_DIR" "$APP_USER" "$APP_GROUP" "775"
    ensure_dir_exists "$MOODLE_DIR" "$APP_USER" "$APP_GROUP" "755"
    
    # Wait for database connection before checking
    wait_for_db_connection "$MOODLE_DATABASE_HOST" "$MOODLE_DATABASE_PORT_NUMBER" "$MOODLE_DATABASE_USER" "$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME"
    
    # Check if this is a pre-built source with database to import
    if [ -f "/opt/moodle-init/moodle_db.sql" ]; then
        # Kiểm tra xem database đã có data chưa
        if check_database_has_data "$MOODLE_DATABASE_HOST" "$MOODLE_DATABASE_PORT_NUMBER" "$MOODLE_DATABASE_USER" "$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME"; then
            info "Database already has data. Skipping import to preserve existing data."
        else
            info "Database is empty. Importing pre-built database..."
            mariadb_remote_execute "$MOODLE_DATABASE_HOST" "$MOODLE_DATABASE_PORT_NUMBER" "$MOODLE_DATABASE_NAME" "$MOODLE_DATABASE_USER" "$MOODLE_DATABASE_PASSWORD" < /opt/moodle-init/moodle_db.sql
            info "Database imported successfully."
        fi
        
        # Also copy pre-built moodledata if available and moodledata has no content files
        if [ -d "/opt/moodle-init/moodledata" ]; then
            # Check if moodledata has content files (excluding system files like .htaccess, .moodle_initialized)
            content_files=$(find "$MOODLE_DATA_DIR" -type f ! -name ".*" ! -name "warning.txt" 2>/dev/null | wc -l)
            
            if [ "$content_files" -eq 0 ]; then
                info "Moodledata has no content files. Copying pre-built moodledata..."
                cp -r /opt/moodle-init/moodledata/* "$MOODLE_DATA_DIR/"
                chown -R "${APP_USER}:${APP_GROUP}" "$MOODLE_DATA_DIR"
                chmod -R 775 "$MOODLE_DATA_DIR"
            else
                info "Moodledata already has content files ($content_files files). Skipping copy to preserve existing data."
            fi
        fi
        
        # Apply environment variable overrides after successful setup
        apply_environment_overrides
    else
        info "No pre-built database found. Running standard upgrade..."
        php "${MOODLE_DIR}/admin/cli/upgrade.php" --non-interactive --allow-unstable >/dev/null || true
        
        # Apply environment variable overrides after upgrade
        apply_environment_overrides
    fi
    
    # Set proper permissions
    chown -R "${APP_USER}:${APP_GROUP}" "$MOODLE_DIR" "$MOODLE_DATA_DIR"
    chmod -R 775 "$MOODLE_DATA_DIR"
    find "${MOODLE_DATA_DIR}/sessions/" -name "sess_*" -delete || true
else
    info "No config.php found. Running standard Moodle installation..."
    
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
    info "Moodle initialization completed."
    
    # Apply environment variable overrides after fresh installation
    apply_environment_overrides
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
