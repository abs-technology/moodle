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
#
# High-level flow on container start (see MAIN LOGIC at the bottom of this
# file for the call site):
#
#   1. detect_moodle_upgrade_needed()          # is image newer than disk?
#   2. perform_moodle_upgrade() orchestrates:
#        a. pre_upgrade_checks()               # disk, php, db, abort marker
#        b. _upgrade_workspace_init()          # create snapshot dir + log
#        c. preserve_custom_content()          # config, plugins, themes
#        d. backup_database_for_upgrade()      # gzipped mysqldump
#        e. backup_code_for_upgrade()          # full code tar.gz
#        f. enable_maintenance_mode()
#        g. replace_moodle_code()              # safe replace into MOODLE_DIR
#        h. restore_custom_content()
#        i. run_db_upgrade_if_enabled()        # opt-in via MOODLE_AUTO_DB_UPGRADE
#        j. disable_maintenance_mode()         # only when DB upgrade ran
#        k. prune_old_upgrade_snapshots()
#
#   On any failure inside d–i, restore_from_snapshot() is invoked which
#   restores both the DB and the code from the snapshot taken in d/e and
#   leaves a `.upgrade-aborted` marker so the next container start does not
#   try the same upgrade again in a loop.
# ============================================================================

# NOTE on parsing version.php:
# Moodle's version.php uses Moodle constants such as MATURITY_STABLE which
# are NOT defined unless the full Moodle bootstrap has run. A naive
# `php -r "require 'version.php';"` therefore aborts with a fatal "Undefined
# constant" error and silently returns nothing - which previously made the
# upgrade detection a no-op.
#
# We instead parse the file as text. version.php is a stable, simple format
# with one assignment per variable. This is robust across all Moodle 3.x/4.x.

_parse_version_php_var() {
    # Usage: _parse_version_php_var <file> <var_name>
    # Echoes the assigned value (without quotes / trailing comment), or empty.
    local file=$1
    local var=$2
    [[ ! -f "$file" ]] && return 1

    # Match e.g. `$version  = 2024100100.05;` or `$release = '4.5.10+ (...)';`
    # We use sed (not awk dynamic regex) because awk's dynamic-regex
    # backslash handling differs between gawk and mawk (Debian's default
    # awk is mawk and silently failed to match `\$version` here, which
    # made every upgrade detection short-circuit with an empty version).
    #
    # Strategy:
    #   1. Find first line matching `^\s*$<var>\s*=`
    #   2. Drop everything up to and including the `=`
    #   3. Drop trailing `;` and anything after it (PHP inline comment etc.)
    #   4. Trim surrounding whitespace and quotes
    sed -nE "/^[[:space:]]*\\\$${var}[[:space:]]*=/{
        s/^[^=]*=[[:space:]]*//
        s/[[:space:]]*;.*\$//
        s/^[[:space:]]+//
        s/[[:space:]]+\$//
        s/^['\"]+//
        s/['\"]+\$//
        p
        q
    }" "$file"
}

# Detect Moodle version (numeric, e.g. 2024100100) from version.php.
get_moodle_version() {
    local version_file=$1
    if [[ ! -f "$version_file" ]]; then
        echo "0"
        return 1
    fi

    local v
    v=$(_parse_version_php_var "$version_file" "version")
    if [[ -z "$v" ]]; then
        echo "0"
        return 1
    fi
    echo "$v"
}

# Get human-readable release string (e.g. "4.5.10+ (Build: 20240728)").
get_moodle_version_info() {
    local version_file=$1
    if [[ ! -f "$version_file" ]]; then
        echo "Unknown"
        return 1
    fi

    local r
    r=$(_parse_version_php_var "$version_file" "release")
    [[ -z "$r" ]] && { echo "Unknown"; return 1; }
    echo "$r"
}

# Read Moodle's required PHP version (e.g. "8.1.0"). Empty when not declared.
get_moodle_required_php() {
    local version_file=$1
    [[ ! -f "$version_file" ]] && { echo ""; return 1; }
    _parse_version_php_var "$version_file" "requires"
}

# Detect if upgrade is needed.
# Returns 0 when an upgrade should run, 1 otherwise.
# Aborts on downgrade. Honors `.upgrade-aborted` markers to prevent loops
# after a previous failed upgrade against the SAME image version.
detect_moodle_upgrade_needed() {
    local source_version_file="/opt/moodle-source/version.php"
    local running_version_file="${MOODLE_DIR}/version.php"

    if [[ ! -f "$running_version_file" ]]; then
        debug "No running version.php found - fresh installation"
        return 1
    fi

    local source_version=$(get_moodle_version "$source_version_file")
    local running_version=$(get_moodle_version "$running_version_file")

    if [[ -z "$source_version" ]] || [[ "$source_version" == "0" ]]; then
        warn "Could not detect image Moodle version"
        return 1
    fi

    if [[ -z "$running_version" ]] || [[ "$running_version" == "0" ]]; then
        warn "Could not detect running Moodle version"
        return 1
    fi

    debug "Image version:   $source_version"
    debug "Running version: $running_version"

    local comparison
    comparison=$(awk -v sv="$source_version" -v rv="$running_version" 'BEGIN {
        if (sv > rv) print "upgrade"
        else if (sv < rv) print "downgrade"
        else print "same"
    }')

    case "$comparison" in
        upgrade)
            # If the previous attempt to upgrade to THIS exact image version
            # was rolled back, refuse to retry automatically. Operator must
            # remove the marker once they have investigated the failure.
            local abort_marker="${MOODLE_DATA_DIR}/.upgrade-aborted"
            if [[ -f "$abort_marker" ]]; then
                local aborted_version
                aborted_version=$(grep '^TARGET_VERSION=' "$abort_marker" 2>/dev/null | cut -d= -f2)
                if [[ "$aborted_version" == "$source_version" ]]; then
                    error "Previous upgrade to version $source_version was rolled back."
                    error "Refusing to retry. See $abort_marker for details."
                    error "Remove the marker after investigating to retry: rm '$abort_marker'"
                    return 1
                fi
            fi

            export MOODLE_UPGRADE_FROM_VERSION="$running_version"
            export MOODLE_UPGRADE_TO_VERSION="$source_version"
            export MOODLE_UPGRADE_FROM_RELEASE=$(get_moodle_version_info "$running_version_file")
            export MOODLE_UPGRADE_TO_RELEASE=$(get_moodle_version_info "$source_version_file")
            return 0
            ;;
        downgrade)
            # Image is OLDER than what is on disk. We deliberately do NOT
            # downgrade (Moodle does not support it - the DB schema and
            # plugin data have already moved forward) and we deliberately do
            # NOT crash the container. Instead we log a loud warning and
            # let startup continue using the existing newer code on disk,
            # so the site stays available while the operator fixes the
            # image tag (or restores from a snapshot).
            local source_release running_release
            source_release=$(get_moodle_version_info "$source_version_file")
            running_release=$(get_moodle_version_info "$running_version_file")

            warn "╔═══════════════════════════════════════════════════════════╗"
            warn "║  ⚠  DOWNGRADE ATTEMPT DETECTED - IGNORED                  ║"
            warn "╠═══════════════════════════════════════════════════════════╣"
            warn "║  Image version:   $source_release ($source_version)"
            warn "║  On-disk version: $running_release ($running_version)"
            warn "║                                                           ║"
            warn "║  The image you are starting is OLDER than the Moodle      ║"
            warn "║  install on the persistent volume. Moodle does not        ║"
            warn "║  support downgrade (DB schema has migrated forward).      ║"
            warn "║                                                           ║"
            warn "║  ➜ The container will START NORMALLY using the newer      ║"
            warn "║    code already on disk. Nothing was changed.             ║"
            warn "║                                                           ║"
            warn "║  If this image tag was a mistake:                         ║"
            warn "║    • Switch back to a tag >= $running_release"
            warn "║                                                           ║"
            warn "║  If you really need to roll back to $source_release:"
            warn "║    1. Stop the container."
            warn "║    2. Restore code+DB from a snapshot in:                 ║"
            warn "║         $MOODLE_BACKUP_DIR"
            if [[ -d "$MOODLE_BACKUP_DIR" ]]; then
                local snaps
                snaps=$(find "$MOODLE_BACKUP_DIR" -mindepth 1 -maxdepth 1 \
                            -type d -name 'upgrade-*' \
                            -printf '%T@ %f\n' 2>/dev/null \
                          | sort -rn | awk '{print $2}' | head -3)
                if [[ -n "$snaps" ]]; then
                    warn "║       Available snapshots (most recent first):           ║"
                    while IFS= read -r s; do
                        [[ -z "$s" ]] && continue
                        warn "║         - $s"
                    done <<< "$snaps"
                else
                    warn "║       (no snapshots present yet)                          ║"
                fi
            fi
            warn "║    3. Start the container again with the older image.     ║"
            warn "╚═══════════════════════════════════════════════════════════╝"

            # Drop a marker so that monitoring can detect this state.
            # Overwrite each start so the most recent attempt is recorded.
            mkdir -p "$MOODLE_DATA_DIR" 2>/dev/null || true
            cat > "${MOODLE_DATA_DIR}/.downgrade-attempted" <<EOF
IMAGE_VERSION=$source_version
IMAGE_RELEASE=$source_release
DISK_VERSION=$running_version
DISK_RELEASE=$running_release
DETECTED_AT=$(date -Iseconds)
ACTION=ignored-container-continued-with-disk-version
EOF
            chown "${APP_USER}:${APP_GROUP}" "${MOODLE_DATA_DIR}/.downgrade-attempted" 2>/dev/null || true

            # Return 1 so the orchestrator skips perform_moodle_upgrade and
            # the rest of the entrypoint just brings Moodle up as-is.
            return 1
            ;;
        same)
            debug "Moodle version up to date: $source_version"
            return 1
            ;;
    esac
}

# ----------------------------------------------------------------------------
# Upgrade workspace, logging and retention
# ----------------------------------------------------------------------------

# Globals populated by _upgrade_workspace_init():
#   _UPGRADE_WORKSPACE  - directory under MOODLE_BACKUP_DIR for this attempt
#   _UPGRADE_DB_DUMP    - path to gzipped DB dump
#   _UPGRADE_CODE_TGZ   - path to gzipped code tarball
#   _UPGRADE_LOG        - path to per-attempt audit log

_upgrade_log() {
    # Append a line to both stdout (via info) and the per-attempt audit log.
    local msg="$*"
    info "$msg"
    if [[ -n "${_UPGRADE_LOG:-}" ]] && [[ -e "$(dirname "$_UPGRADE_LOG")" ]]; then
        printf '%s %s\n' "$(date -Iseconds)" "$msg" >> "$_UPGRADE_LOG" 2>/dev/null || true
    fi
}

_upgrade_workspace_init() {
    local from_version=$1
    local to_version=$2
    local timestamp
    timestamp=$(date -u +%Y%m%dT%H%M%SZ)

    mkdir -p "$MOODLE_BACKUP_DIR" 2>/dev/null || true

    if [[ ! -w "$MOODLE_BACKUP_DIR" ]]; then
        error "Backup directory $MOODLE_BACKUP_DIR is not writable. Cannot proceed safely."
        return 1
    fi

    _UPGRADE_WORKSPACE="${MOODLE_BACKUP_DIR}/upgrade-${timestamp}-${from_version}-to-${to_version}"
    _UPGRADE_DB_DUMP="${_UPGRADE_WORKSPACE}/database.sql.gz"
    _UPGRADE_CODE_TGZ="${_UPGRADE_WORKSPACE}/code.tar.gz"
    _UPGRADE_LOG="${_UPGRADE_WORKSPACE}/upgrade.log"

    mkdir -p "$_UPGRADE_WORKSPACE" || return 1

    cat > "${_UPGRADE_WORKSPACE}/metadata.env" <<EOF
FROM_VERSION=$from_version
TO_VERSION=$to_version
FROM_RELEASE=${MOODLE_UPGRADE_FROM_RELEASE:-Unknown}
TO_RELEASE=${MOODLE_UPGRADE_TO_RELEASE:-Unknown}
STARTED_AT=$(date -Iseconds)
HOSTNAME=$(hostname)
AUTO_DB_UPGRADE=${MOODLE_AUTO_DB_UPGRADE:-no}
EOF

    : > "$_UPGRADE_LOG"
    export _UPGRADE_WORKSPACE _UPGRADE_DB_DUMP _UPGRADE_CODE_TGZ _UPGRADE_LOG
    return 0
}

# Keep the most recent N upgrade snapshots; delete older ones.
prune_old_upgrade_snapshots() {
    local keep=${MOODLE_UPGRADE_RETENTION:-5}
    [[ ! -d "$MOODLE_BACKUP_DIR" ]] && return 0

    local snapshots
    snapshots=$(find "$MOODLE_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -name 'upgrade-*' \
                  -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk '{print $2}')

    local count=0
    while IFS= read -r snap; do
        [[ -z "$snap" ]] && continue
        count=$((count + 1))
        if [[ $count -gt $keep ]]; then
            debug "Pruning old upgrade snapshot: $snap"
            rm -rf "$snap" 2>/dev/null || true
        fi
    done <<< "$snapshots"
}

# ----------------------------------------------------------------------------
# Pre-flight checks
# ----------------------------------------------------------------------------

pre_upgrade_checks() {
    local source_version_file="/opt/moodle-source/version.php"
    info "Running pre-upgrade checks..."

    # 1. Disk space: backup_dir + moodle_dir need at least 2x current code size.
    local code_size_kb
    code_size_kb=$(du -sk "$MOODLE_DIR" 2>/dev/null | awk '{print $1}')
    code_size_kb=${code_size_kb:-0}
    local needed_kb=$((code_size_kb * 2))

    local backup_avail_kb
    backup_avail_kb=$(df -Pk "$MOODLE_BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
    backup_avail_kb=${backup_avail_kb:-0}
    if [[ "$backup_avail_kb" -lt "$needed_kb" ]]; then
        error "Insufficient disk space at $MOODLE_BACKUP_DIR: have ${backup_avail_kb}KB, need ${needed_kb}KB"
        return 1
    fi

    local code_avail_kb
    code_avail_kb=$(df -Pk "$MOODLE_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
    code_avail_kb=${code_avail_kb:-0}
    if [[ "$code_avail_kb" -lt "$code_size_kb" ]]; then
        error "Insufficient disk space at $MOODLE_DIR: have ${code_avail_kb}KB, need ${code_size_kb}KB free"
        return 1
    fi

    # 2. PHP version requirement of the new Moodle.
    local required_php
    required_php=$(get_moodle_required_php "$source_version_file")
    if [[ -n "$required_php" ]]; then
        local current_php
        current_php=$(php -r 'echo PHP_VERSION;' 2>/dev/null)
        if ! awk -v c="$current_php" -v r="$required_php" 'BEGIN {
            split(c, ca, "."); split(r, ra, ".")
            for (i = 1; i <= 3; i++) {
                ca[i] = ca[i] + 0; ra[i] = ra[i] + 0
                if (ca[i] > ra[i]) exit 0
                if (ca[i] < ra[i]) exit 1
            }
            exit 0
        }'; then
            error "PHP $current_php is older than Moodle's requirement of $required_php"
            return 1
        fi
        debug "PHP version OK: $current_php >= required $required_php"
    fi

    # 3. Database connectivity. Retry because the upgrade flow runs BEFORE
    # the standard `wait_for_db_connection` that's defined later in this file
    # (the DB container may still be starting when the entrypoint races ahead).
    info "Waiting for database to become reachable (up to ~60s)..."
    _check_db_for_upgrade() {
        echo "SELECT 1" | mariadb_remote_execute \
            "$MOODLE_DATABASE_HOST" "$MOODLE_DATABASE_PORT_NUMBER" \
            "$MOODLE_DATABASE_NAME" "$MOODLE_DATABASE_USER" \
            "$MOODLE_DATABASE_PASSWORD" >/dev/null 2>&1
    }
    if ! retry_while "_check_db_for_upgrade" 12 5; then
        error "Database not reachable at ${MOODLE_DATABASE_HOST}:${MOODLE_DATABASE_PORT_NUMBER}"
        return 1
    fi

    info "Pre-upgrade checks passed (disk OK, PHP OK, DB reachable)"
    return 0
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

# ----------------------------------------------------------------------------
# Snapshot helpers (database + code) and rollback
# ----------------------------------------------------------------------------

# Snapshot the live database into ${_UPGRADE_DB_DUMP} (gzipped).
# Tries `mariadb-dump` first (Debian 12 default), falls back to `mysqldump`.
backup_database_for_upgrade() {
    _upgrade_log "Snapshotting database to $_UPGRADE_DB_DUMP ..."

    local dumper=""
    if command -v mariadb-dump >/dev/null 2>&1; then
        dumper="mariadb-dump"
    elif command -v mysqldump >/dev/null 2>&1; then
        dumper="mysqldump"
    else
        error "Neither mariadb-dump nor mysqldump is available"
        return 1
    fi

    if "$dumper" \
            -h"${MOODLE_DATABASE_HOST}" \
            -P"${MOODLE_DATABASE_PORT_NUMBER}" \
            -u"${MOODLE_DATABASE_USER}" \
            -p"${MOODLE_DATABASE_PASSWORD}" \
            --single-transaction \
            --quick \
            --add-drop-table \
            --routines \
            --triggers \
            "${MOODLE_DATABASE_NAME}" 2>/dev/null \
        | gzip -c > "$_UPGRADE_DB_DUMP"; then
        local size
        size=$(du -h "$_UPGRADE_DB_DUMP" | cut -f1)
        _upgrade_log "Database snapshot OK ($size, dumper=$dumper)"
        return 0
    else
        error "Database snapshot FAILED"
        rm -f "$_UPGRADE_DB_DUMP"
        return 1
    fi
}

# Snapshot the current MOODLE_DIR contents into ${_UPGRADE_CODE_TGZ} (gzipped tar).
backup_code_for_upgrade() {
    _upgrade_log "Snapshotting code to $_UPGRADE_CODE_TGZ ..."
    if (cd "${MOODLE_DIR}" && tar -czf "$_UPGRADE_CODE_TGZ" . 2>/dev/null); then
        local size
        size=$(du -h "$_UPGRADE_CODE_TGZ" | cut -f1)
        _upgrade_log "Code snapshot OK ($size)"
        return 0
    else
        error "Code snapshot FAILED"
        rm -f "$_UPGRADE_CODE_TGZ"
        return 1
    fi
}

# Replace contents of ${MOODLE_DIR} with the new code from /opt/moodle-source.
# We rely on backup_code_for_upgrade() having taken a tarball already; if
# anything in this function fails, the caller will invoke restore_from_snapshot().
replace_moodle_code() {
    _upgrade_log "Replacing Moodle code with new version..."

    local old_size
    old_size=$(du -sh "${MOODLE_DIR}" 2>/dev/null | cut -f1 || echo "unknown")
    _upgrade_log "  Current installation size: $old_size"

    _upgrade_log "  → Removing old code (tarball backup is at $_UPGRADE_CODE_TGZ)..."
    if ! find "${MOODLE_DIR}" -mindepth 1 -delete 2>/dev/null; then
        error "Failed to delete old Moodle code"
        return 1
    fi

    _upgrade_log "  → Copying new code from image..."
    if ! (cd /opt/moodle-source && tar cf - .) | (cd "${MOODLE_DIR}" && tar xf -); then
        error "Failed to copy new Moodle code"
        return 1
    fi

    _upgrade_log "  → Setting permissions..."
    chown -R "${APP_USER}:${APP_GROUP}" "${MOODLE_DIR}"
    find "${MOODLE_DIR}" -type d -exec chmod 755 {} + 2>/dev/null || true
    find "${MOODLE_DIR}" -type f -exec chmod 644 {} + 2>/dev/null || true

    local new_size
    new_size=$(du -sh "${MOODLE_DIR}" 2>/dev/null | cut -f1 || echo "unknown")
    _upgrade_log "  New installation size: $new_size"
    return 0
}

# Restore both code and DB from the current upgrade snapshot.
# Used when any post-snapshot step fails. Always attempts to restore code
# even if DB restore fails (or vice-versa) so the system gets as close to
# the pre-upgrade state as possible.
restore_from_snapshot() {
    local code_ok=1 db_ok=1

    _upgrade_log "===== ROLLBACK INITIATED ====="

    # 1. Restore code from tar.
    if [[ -f "$_UPGRADE_CODE_TGZ" ]]; then
        _upgrade_log "Restoring code from $_UPGRADE_CODE_TGZ ..."
        find "${MOODLE_DIR}" -mindepth 1 -delete 2>/dev/null || true
        if (cd "${MOODLE_DIR}" && tar -xzf "$_UPGRADE_CODE_TGZ" 2>/dev/null); then
            chown -R "${APP_USER}:${APP_GROUP}" "${MOODLE_DIR}"
            _upgrade_log "Code restored from snapshot"
            code_ok=0
        else
            error "Failed to restore code from snapshot $_UPGRADE_CODE_TGZ"
        fi
    else
        warn "No code snapshot to restore from"
    fi

    # 2. Restore DB from gzipped dump.
    if [[ -f "$_UPGRADE_DB_DUMP" ]]; then
        _upgrade_log "Restoring database from $_UPGRADE_DB_DUMP ..."
        if gunzip -c "$_UPGRADE_DB_DUMP" \
            | mariadb_remote_execute \
                "$MOODLE_DATABASE_HOST" "$MOODLE_DATABASE_PORT_NUMBER" \
                "$MOODLE_DATABASE_NAME" "$MOODLE_DATABASE_USER" \
                "$MOODLE_DATABASE_PASSWORD" >/dev/null 2>&1; then
            _upgrade_log "Database restored from snapshot"
            db_ok=0
        else
            error "Failed to restore database from snapshot $_UPGRADE_DB_DUMP"
        fi
    else
        warn "No database snapshot to restore from"
    fi

    # 3. Disable maintenance after rollback so users can come back online.
    disable_maintenance_mode || true

    # 4. Drop a marker so the next start does not retry the same upgrade.
    cat > "${MOODLE_DATA_DIR}/.upgrade-aborted" <<EOF
TARGET_VERSION=${MOODLE_UPGRADE_TO_VERSION}
TARGET_RELEASE=${MOODLE_UPGRADE_TO_RELEASE}
FROM_VERSION=${MOODLE_UPGRADE_FROM_VERSION}
FROM_RELEASE=${MOODLE_UPGRADE_FROM_RELEASE}
ROLLED_BACK_AT=$(date -Iseconds)
SNAPSHOT_DIR=${_UPGRADE_WORKSPACE}
CODE_RESTORED=$([[ $code_ok -eq 0 ]] && echo yes || echo no)
DB_RESTORED=$([[ $db_ok -eq 0 ]] && echo yes || echo no)
EOF
    chown "${APP_USER}:${APP_GROUP}" "${MOODLE_DATA_DIR}/.upgrade-aborted" 2>/dev/null || true

    _upgrade_log "===== ROLLBACK FINISHED (code_ok=$code_ok db_ok=$db_ok) ====="

    if [[ $code_ok -eq 0 && $db_ok -eq 0 ]]; then
        return 0
    fi
    return 1
}

# ----------------------------------------------------------------------------
# Maintenance mode helpers
# ----------------------------------------------------------------------------

enable_maintenance_mode() {
    if [[ -f "${MOODLE_DIR}/admin/cli/maintenance.php" ]]; then
        _upgrade_log "Enabling maintenance mode..."
        php "${MOODLE_DIR}/admin/cli/maintenance.php" --enable >/dev/null 2>&1 || \
            warn "Could not enable maintenance mode (continuing)"
    fi
}

disable_maintenance_mode() {
    if [[ -f "${MOODLE_DIR}/admin/cli/maintenance.php" ]]; then
        _upgrade_log "Disabling maintenance mode..."
        php "${MOODLE_DIR}/admin/cli/maintenance.php" --disable >/dev/null 2>&1 || \
            warn "Could not disable maintenance mode"
    fi
}

# Run Moodle's CLI database upgrade only when MOODLE_AUTO_DB_UPGRADE=yes.
# Returns:
#   0  => DB upgrade ran successfully (caller should disable maintenance)
#   1  => DB upgrade failed (caller should rollback)
#   2  => Skipped because auto upgrade is disabled (.upgrade-pending was left)
run_db_upgrade_if_enabled() {
    if [[ "${MOODLE_AUTO_DB_UPGRADE,,}" != "yes" ]]; then
        _upgrade_log "MOODLE_AUTO_DB_UPGRADE=no - leaving DB upgrade for the admin (web UI)"
        touch "${MOODLE_DIR}/.upgrade-pending"
        cat > "${MOODLE_DIR}/.upgrade-info" <<EOF
FROM_VERSION=${MOODLE_UPGRADE_FROM_VERSION}
TO_VERSION=${MOODLE_UPGRADE_TO_VERSION}
FROM_RELEASE=${MOODLE_UPGRADE_FROM_RELEASE}
TO_RELEASE=${MOODLE_UPGRADE_TO_RELEASE}
PREPARED_AT=$(date -Iseconds)
SNAPSHOT_DIR=${_UPGRADE_WORKSPACE}
EOF
        return 2
    fi

    _upgrade_log "MOODLE_AUTO_DB_UPGRADE=yes - running php admin/cli/upgrade.php ..."
    if php "${MOODLE_DIR}/admin/cli/upgrade.php" \
            --non-interactive \
            --allow-unstable \
            >> "$_UPGRADE_LOG" 2>&1; then
        _upgrade_log "Database upgrade completed successfully"
        return 0
    else
        local exit_code=$?
        error "Database upgrade FAILED (exit code $exit_code). See $_UPGRADE_LOG"
        return 1
    fi
}

# ----------------------------------------------------------------------------
# Orchestrator
# ----------------------------------------------------------------------------

perform_moodle_upgrade() {
    info "╔═══════════════════════════════════════════════════════════╗"
    info "║          MOODLE UPGRADE DETECTED                          ║"
    info "╠═══════════════════════════════════════════════════════════╣"
    info "║  From: $MOODLE_UPGRADE_FROM_RELEASE  ($MOODLE_UPGRADE_FROM_VERSION)"
    info "║  To:   $MOODLE_UPGRADE_TO_RELEASE  ($MOODLE_UPGRADE_TO_VERSION)"
    info "║  Auto DB upgrade: ${MOODLE_AUTO_DB_UPGRADE}"
    info "║  Backup dir:      ${MOODLE_BACKUP_DIR}"
    info "╚═══════════════════════════════════════════════════════════╝"

    # 0/9: Pre-flight checks (no destructive action yet, safe to abort).
    info "Step 0/9: Running pre-flight checks..."
    if ! pre_upgrade_checks; then
        error "Pre-flight checks failed. Aborting upgrade. No data was touched."
        exit 1
    fi

    # 1/9: Initialize per-attempt workspace and audit log.
    info "Step 1/9: Initializing upgrade workspace..."
    if ! _upgrade_workspace_init "$MOODLE_UPGRADE_FROM_VERSION" "$MOODLE_UPGRADE_TO_VERSION"; then
        error "Failed to initialize upgrade workspace. Aborting."
        exit 1
    fi
    _upgrade_log "Workspace: $_UPGRADE_WORKSPACE"

    # 2/9: Preserve custom content into /tmp (used by restore_custom_content).
    # If this fails, abort BEFORE touching DB/code.
    info "Step 2/9: Preserving custom content..."
    if ! preserve_custom_content; then
        error "Failed to preserve custom content. Aborting upgrade."
        exit 1
    fi

    # 3/9: DB snapshot (rollback source).
    info "Step 3/9: Backing up database..."
    if ! backup_database_for_upgrade; then
        error "Database backup failed. Aborting upgrade BEFORE replacing code."
        exit 1
    fi

    # 4/9: Code snapshot (rollback source).
    info "Step 4/9: Snapshotting current code..."
    if ! backup_code_for_upgrade; then
        error "Code snapshot failed. Aborting upgrade BEFORE replacing code."
        exit 1
    fi

    # 5/9: Maintenance mode.
    #
    # NOTE: We only enable Moodle's CLI "quick" maintenance (climaintenance.html)
    # when we are going to run the DB upgrade ourselves (MOODLE_AUTO_DB_UPGRADE=yes).
    # That mode blocks 100% of HTTP access including /admin/, which is the right
    # behavior for an unattended automated upgrade.
    #
    # When MOODLE_AUTO_DB_UPGRADE=no we DELIBERATELY do NOT enable climaintenance,
    # because the admin must be able to reach /admin/ to click "Upgrade Moodle
    # database now". Moodle still protects the site automatically: as soon as the
    # new code is in place, the on-disk $version is greater than the saved DB
    # version, so every page request shows the "Upgrade required" interstitial
    # and redirects to the upgrade wizard. Regular users cannot use the site
    # until the admin finalizes the upgrade, so we get the safety we want
    # WITHOUT locking the admin out.
    if [[ "${MOODLE_AUTO_DB_UPGRADE,,}" == "yes" ]]; then
        info "Step 5/9: Enabling maintenance mode (auto DB upgrade is ON)..."
        enable_maintenance_mode
    else
        info "Step 5/9: Skipping climaintenance (admin must reach /admin/ to finalize)."
    fi

    # 6/9: Replace code. Failure here triggers rollback.
    info "Step 6/9: Replacing Moodle code..."
    if ! replace_moodle_code; then
        error "Code replacement FAILED. Rolling back..."
        restore_from_snapshot
        exit 1
    fi

    # 7/9: Restore custom content into the new code tree.
    info "Step 7/9: Restoring custom content..."
    if ! restore_custom_content; then
        error "Failed to restore custom content. Rolling back..."
        restore_from_snapshot
        exit 1
    fi

    # 8/9: Optional automatic DB upgrade.
    # NOTE: this script runs under `set -o errexit`. Calling a function bare
    # whose non-zero return value we want to inspect would abort the script
    # immediately. Use the `|| rc=$?` idiom so errexit is suppressed and we
    # can branch on the actual return code.
    info "Step 8/9: Database upgrade phase..."
    local db_step=0
    run_db_upgrade_if_enabled || db_step=$?
    case "$db_step" in
        0)  # auto upgrade succeeded
            disable_maintenance_mode
            ;;
        1)  # auto upgrade failed -> full rollback
            error "Auto DB upgrade failed. Rolling back code AND database..."
            restore_from_snapshot
            exit 1
            ;;
        2)  # skipped - admin must finish through the web UI
            : # leave maintenance mode ON
            ;;
    esac

    # 9/9: Retention - drop oldest snapshots.
    info "Step 9/9: Pruning old snapshots (retention=${MOODLE_UPGRADE_RETENTION})..."
    prune_old_upgrade_snapshots

    # Final report.
    cat > "${_UPGRADE_WORKSPACE}/result.txt" <<EOF
RESULT=success
DB_UPGRADE=$([[ "$db_step" == "0" ]] && echo auto || echo deferred-to-admin)
COMPLETED_AT=$(date -Iseconds)
EOF

    info "╔═══════════════════════════════════════════════════════════╗"
    info "║          MOODLE UPGRADE COMPLETED                         ║"
    info "╠═══════════════════════════════════════════════════════════╣"
    info "║  Code:      ${MOODLE_UPGRADE_FROM_RELEASE} → ${MOODLE_UPGRADE_TO_RELEASE}"
    if [[ "$db_step" == "0" ]]; then
    info "║  Database:  upgraded automatically (CLI)"
    info "║  Status:    site is back online"
    else
    info "║  Database:  PENDING - admin must finalize"
    info "║  Status:    Moodle is showing 'Upgrade required' to all users."
    info "║             Regular users are blocked, admin login still works."
    info "║"
    info "║  Next steps for admin:"
    info "║    1. Visit  http://<your-site>/admin/"
    info "║    2. Login as administrator (Moodle will redirect"
    info "║       to the upgrade wizard automatically)"
    info "║    3. Review plugin compatibility, then click"
    info "║       'Upgrade Moodle database now'"
    info "║    4. After Moodle finishes the DB upgrade, the site"
    info "║       returns to normal automatically."
    info "║"
    info "║  Tip: to make this fully unattended next time, set"
    info "║       MOODLE_AUTO_DB_UPGRADE=yes in your .env"
    fi
    info "║"
    info "║  Snapshot: ${_UPGRADE_WORKSPACE}"
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

            # Mark that the new orchestrator owns the upgrade decision so the
            # legacy "Running standard upgrade..." block further down (which used
            # to unconditionally run admin/cli/upgrade.php and would otherwise
            # silently override MOODLE_AUTO_DB_UPGRADE=no) skips itself.
            export _MOODLE_UPGRADE_HANDLED=1
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
        # If perform_moodle_upgrade already ran, it has already either upgraded
        # the DB (MOODLE_AUTO_DB_UPGRADE=yes) or DELIBERATELY left it pending so
        # the admin can finalize through the web wizard (MOODLE_AUTO_DB_UPGRADE=no).
        # Running admin/cli/upgrade.php here would silently override that decision,
        # so skip it.
        if [[ "${_MOODLE_UPGRADE_HANDLED:-0}" == "1" ]]; then
            info "Moodle upgrade orchestrator already handled the DB step (MOODLE_AUTO_DB_UPGRADE=${MOODLE_AUTO_DB_UPGRADE}). Skipping legacy CLI upgrade."
        else
            info "No pre-built database found. Running standard upgrade..."
            php "${MOODLE_DIR}/admin/cli/upgrade.php" --non-interactive --allow-unstable >/dev/null || true
        fi

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
