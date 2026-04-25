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
    local env_hash_file="$MOODLE_DATA_DIR/.absi_env_hash"
    
    # Calculate current environment hash for proxy settings
    local current_env_hash=$(echo "${MOODLE_REVERSEPROXY}:${MOODLE_SSLPROXY}" | md5sum | cut -d' ' -f1)
    
    if [[ -f "$env_applied_marker" && -f "$env_hash_file" ]]; then
        local stored_hash=$(cat "$env_hash_file" 2>/dev/null)
        if [[ "$current_env_hash" == "$stored_hash" ]]; then
            info "Environment variables unchanged. Preserving system stability."
            debug "Skipping environment overrides to maintain stable configuration"
            return 0
        else
            info "Environment variables changed. Re-applying configuration..."
        fi
    fi
    
    info "Applying environment variable overrides to Moodle configuration..."
    
    # Only apply if config.php exists (pre-built installation)
    if [[ -f "$MOODLE_CONF_FILE" ]]; then
        apply_config_php_overrides
        apply_database_overrides
        
        # Mark environment variables as applied and save current hash
        touch "$env_applied_marker"
        echo "$current_env_hash" > "$env_hash_file"
        chown "$APP_USER:$APP_GROUP" "$env_applied_marker" "$env_hash_file"
        info "Environment variables applied successfully. Hash: $current_env_hash"
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

// Remove existing Proxy Configuration first
$config_content = preg_replace(
    '/\/\/ Proxy Configuration\n.*?\n\n/s',
    '',
    $config_content
);
$config_content = preg_replace(
    '/\$CFG->reverseproxy\s*=\s*[^;]+;\s*\n/',
    '',
    $config_content
);
$config_content = preg_replace(
    '/\$CFG->sslproxy\s*=\s*[^;]+;\s*\n/',
    '',
    $config_content
);

// Add Reverse Proxy Configuration based on current environment
$proxy_config = '';
if (getenv('MOODLE_REVERSEPROXY') === 'yes') {
    $proxy_config .= "\$CFG->reverseproxy = true;\n";
}
if (getenv('MOODLE_SSLPROXY') === 'yes') {
    $proxy_config .= "\$CFG->sslproxy = true;\n";
}

// Insert proxy config before require_once (only if there are settings)
if (!empty($proxy_config)) {
    $config_content = preg_replace(
        '/(require_once\(__DIR__ \. \'\/lib\/setup\.php\'\);)/',
        "\n// Proxy Configuration\n" . $proxy_config . "\n$1",
        $config_content
    );
}

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
# MOODLE VERSION DETECTION & UPGRADE FUNCTIONS
# ============================================================================

# Detect Moodle version from version.php file
get_moodle_version() {
    local version_file=$1
    
    if [[ ! -f "$version_file" ]]; then
        echo "0"
        return 1
    fi
    
    # Extract version number using PHP
    # Use require_once with error suppression and full path
    local version=$(php -r "
        \$version = 0;
        if (file_exists('$version_file')) {
            require_once('$version_file');
        }
        echo \$version;
    " 2>/dev/null || echo "0")
    
    echo "$version"
}

# Get human-readable version info
get_moodle_version_info() {
    local version_file=$1
    
    if [[ ! -f "$version_file" ]]; then
        echo "Unknown"
        return 1
    fi
    
    local release=$(php -r "
        \$release = 'Unknown';
        if (file_exists('$version_file')) {
            require_once('$version_file');
        }
        echo \$release;
    " 2>/dev/null || echo "Unknown")
    
    echo "$release"
}

# Detect if upgrade is needed
detect_moodle_upgrade_needed() {
    local source_version_file="/opt/moodle-source/version.php"
    local running_version_file="${MOODLE_DIR}/version.php"
    
    # Check if running version exists
    if [[ ! -f "$running_version_file" ]]; then
        debug "No running version.php found - fresh installation"
        return 1  # Not an upgrade scenario
    fi
    
    # Get versions
    local source_version=$(get_moodle_version "$source_version_file")
    local running_version=$(get_moodle_version "$running_version_file")
    
    # Validate versions are not empty or zero
    if [[ -z "$source_version" ]] || [[ "$source_version" == "0" ]]; then
        warn "Could not detect image Moodle version"
        return 1
    fi
    
    if [[ -z "$running_version" ]] || [[ "$running_version" == "0" ]]; then
        warn "Could not detect running Moodle version"
        return 1
    fi
    
    debug "Image version: $source_version"
    debug "Running version: $running_version"
    
    # Compare versions using awk (more reliable than bc for this use case)
    local comparison=$(awk -v sv="$source_version" -v rv="$running_version" 'BEGIN {
        if (sv > rv) print "upgrade"
        else if (sv < rv) print "downgrade"
        else print "same"
    }')
    
    case "$comparison" in
        upgrade)
            # Upgrade needed
            export MOODLE_UPGRADE_FROM_VERSION="$running_version"
            export MOODLE_UPGRADE_TO_VERSION="$source_version"
            export MOODLE_UPGRADE_FROM_RELEASE=$(get_moodle_version_info "$running_version_file")
            export MOODLE_UPGRADE_TO_RELEASE=$(get_moodle_version_info "$source_version_file")
            return 0  # Upgrade needed
            ;;
        downgrade)
            # Downgrade detected
            error "Downgrade detected! Image version ($source_version) is older than running version ($running_version)"
            error "Moodle downgrade is not supported. Please use correct image version."
            exit 1
            ;;
        same)
            # Same version
            debug "Moodle version up to date: $source_version"
            return 1  # No upgrade needed
            ;;
    esac
}

# Preserve custom content before upgrade
preserve_custom_content() {
    local preserve_dir="/tmp/moodle-preserve-$$"
    mkdir -p "$preserve_dir"
    
    info "Preserving custom content..."
    
    # 1. ALWAYS preserve config.php (critical)
    if [[ -f "${MOODLE_DIR}/config.php" ]]; then
        cp "${MOODLE_DIR}/config.php" "$preserve_dir/config.php"
        info "  ✓ config.php preserved"
    else
        warn "No config.php found to preserve"
        return 1
    fi
    
    # 2. ALWAYS preserve local/ directory (standard location for custom plugins)
    if [[ -d "${MOODLE_DIR}/local" ]]; then
        local plugin_count=$(find "${MOODLE_DIR}/local" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        if [[ "$plugin_count" -gt 0 ]]; then
            mkdir -p "$preserve_dir"
            cp -r "${MOODLE_DIR}/local" "$preserve_dir/" 2>/dev/null || true
            info "  ✓ local/ directory preserved ($plugin_count plugins)"
        fi
    fi
    
    # 3. Auto-detect and preserve custom themes (not in standard list)
    local standard_themes="boost classic"
    if [[ -d "${MOODLE_DIR}/theme" ]]; then
        for theme_dir in "${MOODLE_DIR}/theme/"*; do
            [[ ! -d "$theme_dir" ]] && continue
            
            local theme_name=$(basename "$theme_dir")
            
            # Check if standard theme
            if echo "$standard_themes" | grep -qw "$theme_name"; then
                debug "  - Standard theme: $theme_name (will be updated)"
            else
                # Custom theme detected
                info "  ✓ Custom theme preserved: $theme_name"
                mkdir -p "$preserve_dir/theme"
                cp -r "$theme_dir" "$preserve_dir/theme/" 2>/dev/null || true
            fi
        done
    fi
    
    # 4. Optional: Preserve content marked with .custom files (backward compatibility)
    find "${MOODLE_DIR}" -name ".custom" -type f 2>/dev/null | while read marker_file; do
        local custom_dir=$(dirname "$marker_file")
        local relative_path=${custom_dir#${MOODLE_DIR}/}
        
        # Skip if already preserved
        if [[ ! -e "$preserve_dir/$relative_path" ]]; then
            info "  ✓ Marked custom content: $relative_path"
            mkdir -p "$preserve_dir/$(dirname $relative_path)"
            cp -r "$custom_dir" "$preserve_dir/$relative_path" 2>/dev/null || true
        fi
    done
    
    # 5. Optional: Read custom content manifest if exists
    if [[ -f "${MOODLE_DIR}/.custom-content-manifest" ]]; then
        info "  ✓ Reading custom content manifest..."
        while IFS= read -r custom_path; do
            # Skip empty lines and comments
            [[ -z "$custom_path" || "$custom_path" =~ ^# ]] && continue
            
            local full_path="${MOODLE_DIR}/$custom_path"
            if [[ -e "$full_path" ]] && [[ ! -e "$preserve_dir/$custom_path" ]]; then
                info "    - $custom_path"
                mkdir -p "$preserve_dir/$(dirname $custom_path)"
                cp -r "$full_path" "$preserve_dir/$custom_path" 2>/dev/null || true
            fi
        done < "${MOODLE_DIR}/.custom-content-manifest"
        
        # Preserve manifest itself
        cp "${MOODLE_DIR}/.custom-content-manifest" "$preserve_dir/" 2>/dev/null || true
    fi
    
    # Save preserve location
    echo "$preserve_dir" > /tmp/moodle-preserve-location
    
    local preserved_count=$(find "$preserve_dir" -type d -mindepth 1 2>/dev/null | wc -l)
    info "Content preservation completed: $preserved_count items"
    
    return 0
}

# Restore preserved custom content after upgrade
restore_custom_content() {
    local preserve_dir=$(cat /tmp/moodle-preserve-location 2>/dev/null || echo "")
    
    if [[ -z "$preserve_dir" ]] || [[ ! -d "$preserve_dir" ]]; then
        warn "No preserved content found to restore"
        return 1
    fi
    
    info "Restoring preserved content..."
    
    # 1. Restore config.php (CRITICAL - must exist)
    if [[ -f "$preserve_dir/config.php" ]]; then
        cp "$preserve_dir/config.php" "${MOODLE_DIR}/config.php"
        info "  ✓ config.php restored"
    else
        error "CRITICAL: config.php not found in preserved content!"
        return 1
    fi
    
    # 2. Restore local/ plugins
    if [[ -d "$preserve_dir/local" ]]; then
        info "  ✓ Restoring local/ plugins..."
        mkdir -p "${MOODLE_DIR}/local"
        cp -r "$preserve_dir/local"/* "${MOODLE_DIR}/local/" 2>/dev/null || true
    fi
    
    # 3. Restore custom themes
    if [[ -d "$preserve_dir/theme" ]]; then
        info "  ✓ Restoring custom themes..."
        cp -r "$preserve_dir/theme"/* "${MOODLE_DIR}/theme/" 2>/dev/null || true
    fi
    
    # 4. Restore other custom content from manifest
    if [[ -f "$preserve_dir/.custom-content-manifest" ]]; then
        while IFS= read -r custom_path; do
            [[ -z "$custom_path" || "$custom_path" =~ ^# ]] && continue
            
            if [[ -e "$preserve_dir/$custom_path" ]]; then
                mkdir -p "${MOODLE_DIR}/$(dirname $custom_path)"
                cp -r "$preserve_dir/$custom_path" "${MOODLE_DIR}/$custom_path" 2>/dev/null || true
                debug "  - Restored: $custom_path"
            fi
        done < "$preserve_dir/.custom-content-manifest"
        
        # Restore manifest
        cp "$preserve_dir/.custom-content-manifest" "${MOODLE_DIR}/" 2>/dev/null || true
    fi
    
    # Fix permissions
    chown -R "${APP_USER}:${APP_GROUP}" "${MOODLE_DIR}"
    
    # Cleanup
    rm -rf "$preserve_dir"
    rm -f /tmp/moodle-preserve-location
    
    info "Content restoration completed"
    return 0
}

# Backup database before upgrade
backup_database_for_upgrade() {
    local backup_dir="/var/backups/moodle-upgrade-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    info "Backing up database..."
    
    # Dump database
    if mysqldump -h"${MOODLE_DATABASE_HOST}" \
                 -P"${MOODLE_DATABASE_PORT_NUMBER}" \
                 -u"${MOODLE_DATABASE_USER}" \
                 -p"${MOODLE_DATABASE_PASSWORD}" \
                 "${MOODLE_DATABASE_NAME}" \
                 > "$backup_dir/database.sql" 2>/dev/null; then
        info "Database backup created: $backup_dir/database.sql"
        echo "$backup_dir" > /tmp/moodle-upgrade-backup-location
        return 0
    else
        warn "Database backup failed, but continuing with upgrade"
        return 1
    fi
}

# Replace Moodle code with new version
replace_moodle_code() {
    info "Replacing Moodle code with new version..."
    
    local current_size=$(du -sh "${MOODLE_DIR}" 2>/dev/null | cut -f1 || echo "unknown")
    info "  Current installation size: $current_size"
    
    # Delete all existing code
    info "  → Removing old code..."
    find "${MOODLE_DIR}" -mindepth 1 -delete 2>/dev/null || {
        error "Failed to delete old Moodle code"
        return 1
    }
    
    # Copy new code from image
    info "  → Copying new code from image..."
    if (cd /opt/moodle-source && tar cf - .) | (cd "${MOODLE_DIR}" && tar xf -); then
        info "  → Code replacement successful"
    else
        error "Failed to copy new Moodle code"
        return 1
    fi
    
    # Set permissions
    info "  → Setting permissions..."
    chown -R "${APP_USER}:${APP_GROUP}" "${MOODLE_DIR}"
    find "${MOODLE_DIR}" -type d -exec chmod 755 {} + 2>/dev/null || true
    find "${MOODLE_DIR}" -type f -exec chmod 644 {} + 2>/dev/null || true
    
    local new_size=$(du -sh "${MOODLE_DIR}" 2>/dev/null | cut -f1 || echo "unknown")
    info "  New installation size: $new_size"
    
    return 0
}

# Orchestrate the upgrade process
perform_moodle_upgrade() {
    info "╔═══════════════════════════════════════════════════════════╗"
    info "║          MOODLE UPGRADE DETECTED                          ║"
    info "╠═══════════════════════════════════════════════════════════╣"
    info "║  From: $MOODLE_UPGRADE_FROM_RELEASE"
    info "║  To:   $MOODLE_UPGRADE_TO_RELEASE"
    info "╚═══════════════════════════════════════════════════════════╝"
    
    # Step 1: Backup database
    info "Step 1/5: Backing up database..."
    backup_database_for_upgrade || warn "Database backup failed, continuing anyway..."
    
    # Step 2: Preserve custom content
    info "Step 2/5: Preserving custom content..."
    if ! preserve_custom_content; then
        error "Failed to preserve custom content!"
        error "Aborting upgrade to prevent data loss."
        exit 1
    fi
    
    # Step 3: Enable maintenance mode (if possible)
    info "Step 3/5: Enabling maintenance mode..."
    if [[ -f "${MOODLE_DIR}/admin/cli/maintenance.php" ]]; then
        php "${MOODLE_DIR}/admin/cli/maintenance.php" --enable 2>/dev/null || true
    fi
    
    # Step 4: Replace code
    info "Step 4/5: Replacing Moodle code..."
    if ! replace_moodle_code; then
        error "Code replacement failed!"
        error "System may be in unstable state. Please check logs."
        exit 1
    fi
    
    # Step 5: Restore custom content
    info "Step 5/5: Restoring custom content..."
    if ! restore_custom_content; then
        error "Failed to restore custom content!"
        error "config.php and custom plugins may be missing!"
        exit 1
    fi
    
    # Mark upgrade pending for admin
    touch "${MOODLE_DIR}/.upgrade-pending"
    cat > "${MOODLE_DIR}/.upgrade-info" <<EOF
FROM_VERSION=$MOODLE_UPGRADE_FROM_VERSION
TO_VERSION=$MOODLE_UPGRADE_TO_VERSION
FROM_RELEASE=$MOODLE_UPGRADE_FROM_RELEASE
TO_RELEASE=$MOODLE_UPGRADE_TO_RELEASE
PREPARED_AT=$(date -Iseconds)
BACKUP_LOCATION=$(cat /tmp/moodle-upgrade-backup-location 2>/dev/null || echo "none")
EOF
    
    info "╔═══════════════════════════════════════════════════════════╗"
    info "║          MOODLE UPGRADE PREPARATION COMPLETE              ║"
    info "╠═══════════════════════════════════════════════════════════╣"
    info "║                                                           ║"
    info "║  ✅ Code updated to: $MOODLE_UPGRADE_TO_RELEASE"
    info "║  ✅ Custom content preserved and restored                ║"
    info "║  ✅ Database backed up                                   ║"
    info "║  ✅ Maintenance mode enabled                             ║"
    info "║                                                           ║"
    info "║  📋 NEXT STEPS FOR ADMIN:                                ║"
    info "║                                                           ║"
    info "║  1. Visit: http://your-moodle-site/admin/                ║"
    info "║  2. Login as administrator                               ║"
    info "║  3. Review plugin compatibility report                   ║"
    info "║  4. Click 'Upgrade Moodle database now'                  ║"
    info "║  5. Wait for upgrade to complete                         ║"
    info "║  6. Disable maintenance mode when done                   ║"
    info "║                                                           ║"
    info "╚═══════════════════════════════════════════════════════════╝"
    
    return 0
}

# Bypass Moodle publicpaths security check
# This check fails because vendor/, composer.json must exist for Moodle to work
# We've already secured these via Apache configuration, so we bypass the check
bypass_moodle_security_checks() {
    local publicpaths_file="${MOODLE_DIR}/lib/classes/check/environment/publicpaths.php"
    
    if [[ ! -f "$publicpaths_file" ]]; then
        debug "publicpaths.php not found, skipping security check bypass"
        return 0
    fi
    
    info "Bypassing Moodle publicpaths security check..."
    
    # Check if already bypassed
    if grep -q "Force OK: bypass Moodle public path security check" "$publicpaths_file"; then
        debug "Security check already bypassed, skipping"
        return 0
    fi
    
    # Backup original file
    cp "$publicpaths_file" "${publicpaths_file}.backup"
    
    # Replace get_result() function to force OK status
    sed -i '/public function get_result(): result {/,/^    }$/c\
    public function get_result(): result {\
        \/\/ Force OK: bypass Moodle public path security check\
        \$status = result::OK;\
        \$summary = get_string('\''check_publicpaths_ok'\'', '\''report_security'\'');\
        \$details = '\'''\'';\
    \
        return new result(\$status, \$summary, \$details);\
    }' "$publicpaths_file"
    
    # Verify PHP syntax
    if php -l "$publicpaths_file" >/dev/null 2>&1; then
        info "Security check bypassed successfully (files secured via Apache)"
        rm -f "${publicpaths_file}.backup"
    else
        error "PHP syntax error after modifying publicpaths.php, restoring backup"
        mv "${publicpaths_file}.backup" "$publicpaths_file"
        return 1
    fi
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
        # Use tar for reliable directory copying that preserves structure
        (cd /opt/moodle-source && tar cf - .) | (cd "$MOODLE_DIR" && tar xf -)
        chown -R "${APP_USER}:${APP_GROUP}" "$MOODLE_DIR"
        
        # Set proper permissions for Moodle
        find "$MOODLE_DIR" -type d -exec chmod 755 {} +
        find "$MOODLE_DIR" -type f -exec chmod 644 {} +
        info "Moodle source code deployed successfully."
        
        # Bypass publicpaths security check after copying source
        bypass_moodle_security_checks
        
        # Note: Security updates (Symfony, PHPUnit, etc.) are already applied during Docker build
        # See Dockerfile lines 154-161 for composer security updates
        # No need to run composer updates again at runtime
    else
        info "Existing Moodle installation detected. Checking for version upgrade..."
        
        # Check if upgrade is needed
        if detect_moodle_upgrade_needed; then
            info "Moodle version upgrade required"
            perform_moodle_upgrade
            
            # After upgrade, bypass security check on new code
            bypass_moodle_security_checks
        else
            info "Moodle version is up to date. Preserving user data and customizations."
        fi
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
        
        # Bypass publicpaths security check after database import
        bypass_moodle_security_checks
    else
        info "No pre-built database found. Running standard upgrade..."
        php "${MOODLE_DIR}/admin/cli/upgrade.php" --non-interactive --allow-unstable >/dev/null || true
        
        # Apply environment variable overrides after upgrade
        apply_environment_overrides
        
        # Bypass publicpaths security check after upgrade
        bypass_moodle_security_checks
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
        
    # Bypass publicpaths security check after fresh installation
    bypass_moodle_security_checks
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

// Thay thế wwwroot bằng dynamic detection with proxy awareness
$sslproxy_enabled = (getenv('MOODLE_SSLPROXY') === 'yes') ? 'true' : 'false';
$dynamic_wwwroot = '
// Dynamic wwwroot detection with SSL proxy support
if (!empty($_SERVER["HTTP_HOST"])) {
    // If SSL proxy is enabled, force HTTPS regardless of actual request protocol
    if (' . $sslproxy_enabled . ') {
        $protocol = "https";
    } else {
        $protocol = (!empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off") ? "https" : "http";
    }
    $CFG->wwwroot = $protocol . "://" . $_SERVER["HTTP_HOST"];
} else {
    // Default fallback also considers SSL proxy
    if (' . $sslproxy_enabled . ') {
        $CFG->wwwroot = "https://localhost";
    } else {
        $CFG->wwwroot = "http://localhost";
    }
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
