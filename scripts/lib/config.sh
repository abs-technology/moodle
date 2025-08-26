#!/bin/bash
# Copyright Absi Technology. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Central Configuration Library for Absi Moodle

. /scripts/lib/logging.sh

# ============================================================================
# CORE APPLICATION CONFIGURATION
# ============================================================================

# Application User & Group
export APP_USER="${APP_USER:-absiuser}"
export APP_GROUP="${APP_GROUP:-absiuser}"
export APP_UID="${APP_UID:-1000}"
export APP_GID="${APP_GID:-1000}"

# Application Paths
export MOODLE_DIR="${MOODLE_DIR:-/var/www/html}"
export MOODLE_DATA_DIR="${MOODLE_DATA_DIR:-/var/www/moodledata}"
export MOODLE_SOURCE_DIR="${MOODLE_SOURCE_DIR:-/opt/moodle-source}"

# ============================================================================
# PHP CONFIGURATION
# ============================================================================

export PHP_VERSION="${PHP_VERSION:-8.2}"
export PHP_INI_PATH="/etc/php/${PHP_VERSION}/fpm/php.ini"
export PHP_FPM_WWW_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
export PHP_FPM_SOCKET="/var/run/php/php${PHP_VERSION}-fpm.sock"

# PHP Settings
export PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-256M}"
export PHP_MAX_INPUT_VARS="${PHP_MAX_INPUT_VARS:-5000}"
export PHP_POST_MAX_SIZE="${PHP_POST_MAX_SIZE:-50M}"
export PHP_UPLOAD_MAX_FILESIZE="${PHP_UPLOAD_MAX_FILESIZE:-40M}"
export PHP_MAX_EXECUTION_TIME="${PHP_MAX_EXECUTION_TIME:-300}"
export PHP_MAX_FILE_UPLOADS="${PHP_MAX_FILE_UPLOADS:-20}"

# ============================================================================
# WEB SERVER CONFIGURATION
# ============================================================================

export WEB_SERVER_DAEMON_USER="${WEB_SERVER_DAEMON_USER:-$APP_USER}"
export WEB_SERVER_DAEMON_GROUP="${WEB_SERVER_DAEMON_GROUP:-$APP_GROUP}"
export WEB_SERVER_NAME="${WEB_SERVER_NAME:-localhost}"
export WEB_SERVER_ADMIN="${WEB_SERVER_ADMIN:-webmaster@localhost}"

# Apache Paths
export APACHE_CONFIG_DIR="/etc/apache2"
export APACHE_SITES_DIR="/etc/apache2/sites-available"
export APACHE_LOG_DIR="/var/log/apache2"
export APACHE_RUN_DIR="/var/run/apache2"
export APACHE_LOCK_DIR="/var/lock/apache2"

# ============================================================================
# SSL CONFIGURATION
# ============================================================================

export SSL_CERT_DIR="/etc/ssl/certs"
export SSL_KEY_DIR="/etc/ssl/private"
export SSL_CERT_FILE="${SSL_CERT_DIR}/${WEB_SERVER_NAME}.crt"
export SSL_KEY_FILE="${SSL_KEY_DIR}/${WEB_SERVER_NAME}.key"

# SSL Certificate Details
export SSL_COUNTRY="${SSL_COUNTRY:-VN}"
export SSL_STATE="${SSL_STATE:-HCM}"
export SSL_CITY="${SSL_CITY:-HCM}"
export SSL_ORGANIZATION="${SSL_ORGANIZATION:-ABSI}"
export SSL_COMMON_NAME="${SSL_COMMON_NAME:-$WEB_SERVER_NAME}"

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================

# Moodle Database Settings
export MOODLE_DATABASE_TYPE="${MOODLE_DATABASE_TYPE:-mariadb}"
export MOODLE_DATABASE_HOST="${MOODLE_DATABASE_HOST:-mariadb}"
export MOODLE_DATABASE_PORT_NUMBER="${MOODLE_DATABASE_PORT_NUMBER:-3306}"
export MOODLE_DATABASE_NAME="${MOODLE_DATABASE_NAME:-absi_moodle_db}"
export MOODLE_DATABASE_USER="${MOODLE_DATABASE_USER:-absi_moodle_user}"
export MOODLE_DATABASE_PASSWORD="${MOODLE_DATABASE_PASSWORD:-password}"

# MariaDB Client Settings
export MARIADB_HOST="${MARIADB_HOST:-$MOODLE_DATABASE_HOST}"
export MARIADB_PORT_NUMBER="${MARIADB_PORT_NUMBER:-$MOODLE_DATABASE_PORT_NUMBER}"
export MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"
export MARIADB_USER="${MARIADB_USER:-$MOODLE_DATABASE_USER}"
export MARIADB_PASSWORD="${MARIADB_PASSWORD:-$MOODLE_DATABASE_PASSWORD}"
export MARIADB_DATABASE="${MARIADB_DATABASE:-$MOODLE_DATABASE_NAME}"
export MARIADB_CHARACTER_SET="${MARIADB_CHARACTER_SET:-utf8mb4}"
export MARIADB_COLLATE="${MARIADB_COLLATE:-utf8mb4_unicode_ci}"

# ============================================================================
# MOODLE APPLICATION CONFIGURATION
# ============================================================================

export MOODLE_USERNAME="${MOODLE_USERNAME:-absi_admin}"
export MOODLE_PASSWORD="${MOODLE_PASSWORD:-password}"
export MOODLE_EMAIL="${MOODLE_EMAIL:-henry@absi.edu.vn}"
export MOODLE_SITE_NAME="${MOODLE_SITE_NAME:-Absi Technology Moodle LMS}"
export MOODLE_SITE_FULLNAME="${MOODLE_SITE_FULLNAME:-Absi Technology Learning Management System}"
export MOODLE_SITE_SHORTNAME="${MOODLE_SITE_SHORTNAME:-ABSI-LMS}"
export MOODLE_CRON_MINUTES="${MOODLE_CRON_MINUTES:-1}"
export MOODLE_HOST="${MOODLE_HOST:-localhost}"
export MOODLE_REVERSEPROXY="${MOODLE_REVERSEPROXY:-no}"
export MOODLE_SSLPROXY="${MOODLE_SSLPROXY:-no}"

# ============================================================================
# SYSTEM PATHS
# ============================================================================

export SYSTEM_LOG_DIR="/var/log"
export SYSTEM_RUN_DIR="/var/run"
export SYSTEM_LOCK_DIR="/var/lock"
export SYSTEM_TMP_DIR="/tmp"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Print current configuration
print_config() {
    debug "=== ABSI MOODLE CONFIGURATION ==="
    debug "App User/Group: $APP_USER:$APP_GROUP ($APP_UID:$APP_GID)"
    debug "PHP Version: $PHP_VERSION"
    debug "Moodle Dir: $MOODLE_DIR"
    debug "Moodle Data Dir: $MOODLE_DATA_DIR"
    debug "Database: $MOODLE_DATABASE_TYPE://$MOODLE_DATABASE_HOST:$MOODLE_DATABASE_PORT_NUMBER/$MOODLE_DATABASE_NAME"
    debug "Web Server: $WEB_SERVER_NAME"
    debug "SSL Certificate: $SSL_CERT_FILE"
    debug "=================================="
}

# Validate configuration
validate_config() {
    local errors=0
    
    # Check required variables
    if [[ -z "$APP_USER" ]]; then
        error "APP_USER is not set"
        ((errors++))
    fi
    
    if [[ -z "$PHP_VERSION" ]]; then
        error "PHP_VERSION is not set"
        ((errors++))
    fi
    
    if [[ -z "$MOODLE_DATABASE_HOST" ]]; then
        error "MOODLE_DATABASE_HOST is not set"
        ((errors++))
    fi
    
    return $errors
}

# Load configuration and validate
load_config() {
    debug "Loading Absi Moodle configuration..."
    
    if validate_config; then
        debug "Configuration validation passed"
        if [[ "${DEBUG:-false}" == "true" ]]; then
            print_config
        fi
    else
        error "Configuration validation failed"
        exit 1
    fi
}

debug "Configuration library loaded" 