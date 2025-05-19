#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

# Load logging functions
. /opt/absi/entrypoint/lib/logging.sh

# Default values for environment variables
: "${MOODLE_DATABASE_TYPE:=mariadb}"
: "${MOODLE_DATABASE_HOST:=mariadb}"
: "${MOODLE_DATABASE_PORT:=3306}"
: "${MOODLE_DATABASE_NAME:=moodle}"
: "${MOODLE_DATABASE_USER:=moodle}"
: "${MOODLE_DATABASE_PASSWORD:=}"
: "${MOODLE_DATABASE_PREFIX:=mdl_}"
: "${MOODLE_WWWROOT:=http://localhost}"
: "${MOODLE_DATAROOT:=/var/www/moodledata}"
: "${MOODLE_ADMIN_USER:=admin}"
: "${MOODLE_ADMIN_PASSWORD:=}"
: "${MOODLE_ADMIN_EMAIL:=admin@example.com}"
: "${MOODLE_LANG:=en}"
: "${MOODLE_SITE_NAME:=Moodle ABSI}"
: "${MOODLE_SITE_FULLNAME:=Moodle powered by ABS Technology}"
: "${MOODLE_SITE_SHORTNAME:=Moodle ABSI}"
: "${MOODLE_SITE_DESCRIPTION:=Moodle Learning Management System powered by ABS Technology}"
: "${MOODLE_SKIP_INSTALL:=}"
: "${MOODLE_SKIP_BOOTSTRAP:=}"
: "${MOODLE_REVERSEPROXY:=false}"
: "${MOODLE_SSLPROXY:=false}"
: "${MOODLE_ALLOW_INSTALL:=false}"
: "${MOODLE_RECONFIGURE:=}"
: "${MOODLE_TIMEZONE:=Asia/Ho_Chi_Minh}"

# SMTP configuration
: "${MOODLE_SMTP_HOST:=}"
: "${MOODLE_SMTP_PORT:=25}"
: "${MOODLE_SMTP_USER:=}"
: "${MOODLE_SMTP_PASSWORD:=}"
: "${MOODLE_SMTP_PROTOCOL:=}"  # tls, ssl, or empty
: "${MOODLE_NO_REPLY_ADDRESS:=noreply@example.com}"

# PHP configuration
: "${PHP_MAX_EXECUTION_TIME:=600}"
: "${PHP_MEMORY_LIMIT:=512M}"
: "${PHP_UPLOAD_MAX_FILESIZE:=1G}"
: "${PHP_POST_MAX_SIZE:=1G}"
: "${APACHE_DOCUMENT_ROOT:=/var/www/html}"

# Export all variables
export MOODLE_DATABASE_TYPE
export MOODLE_DATABASE_HOST
export MOODLE_DATABASE_PORT
export MOODLE_DATABASE_NAME
export MOODLE_DATABASE_USER
export MOODLE_DATABASE_PASSWORD
export MOODLE_DATABASE_PREFIX
export MOODLE_WWWROOT
export MOODLE_DATAROOT
export MOODLE_ADMIN_USER
export MOODLE_ADMIN_PASSWORD
export MOODLE_ADMIN_EMAIL
export MOODLE_LANG
export MOODLE_SITE_NAME
export MOODLE_SITE_FULLNAME
export MOODLE_SITE_SHORTNAME
export MOODLE_SITE_DESCRIPTION
export MOODLE_SKIP_INSTALL
export MOODLE_SKIP_BOOTSTRAP
export MOODLE_REVERSEPROXY
export MOODLE_SSLPROXY
export MOODLE_ALLOW_INSTALL
export MOODLE_RECONFIGURE
export MOODLE_TIMEZONE
export MOODLE_SMTP_HOST
export MOODLE_SMTP_PORT
export MOODLE_SMTP_USER
export MOODLE_SMTP_PASSWORD
export MOODLE_SMTP_PROTOCOL
export MOODLE_NO_REPLY_ADDRESS
export PHP_MAX_EXECUTION_TIME
export PHP_MEMORY_LIMIT
export PHP_UPLOAD_MAX_FILESIZE
export PHP_POST_MAX_SIZE
export APACHE_DOCUMENT_ROOT

# Validate required environment variables
validate_env_vars() {
    local missing_vars=()
    local warning_vars=()
    
    # Check for required variables
    if [ -z "$MOODLE_DATABASE_PASSWORD" ] && [ -z "$MOODLE_SKIP_INSTALL" ]; then
        warning_vars+=("MOODLE_DATABASE_PASSWORD")
    fi
    
    if [ -z "$MOODLE_ADMIN_PASSWORD" ] && [ -z "$MOODLE_SKIP_INSTALL" ]; then
        warning_vars+=("MOODLE_ADMIN_PASSWORD")
    fi
    
    # If any required variables are missing, log warning but continue
    if [ ${#warning_vars[@]} -gt 0 ]; then
        log_warn "The following environment variables are not set:"
        for var in "${warning_vars[@]}"; do
            log_warn "  - $var"
        done
        log_warn "Some Moodle functionality may be limited or unavailable."
    fi
    
    # Validate SMTP configuration
    if [ -n "$MOODLE_SMTP_HOST" ]; then
        log_info "SMTP configuration detected"
        if [ -z "$MOODLE_SMTP_USER" ] || [ -z "$MOODLE_SMTP_PASSWORD" ]; then
            log_warn "SMTP host specified but username or password is missing"
        fi
    fi
}

# Apply PHP configuration from environment variables
apply_php_config() {
    log_info "Applying PHP configuration from environment variables"
    
    # Update PHP configuration
    sed -i "s/^memory_limit.*/memory_limit = ${PHP_MEMORY_LIMIT}/" /usr/local/etc/php/conf.d/moodle.ini
    sed -i "s/^max_execution_time.*/max_execution_time = ${PHP_MAX_EXECUTION_TIME}/" /usr/local/etc/php/conf.d/moodle.ini
    sed -i "s/^upload_max_filesize.*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" /usr/local/etc/php/conf.d/moodle.ini
    sed -i "s/^post_max_size.*/post_max_size = ${PHP_POST_MAX_SIZE}/" /usr/local/etc/php/conf.d/moodle.ini
    
    log_info "PHP configuration updated"
}

# Apply Apache configuration from environment variables
apply_apache_config() {
    log_info "Applying Apache configuration from environment variables"
    
    # Update document root if needed
    if [ "$APACHE_DOCUMENT_ROOT" != "/var/www/html" ]; then
        sed -i "s|DocumentRoot /var/www/html|DocumentRoot ${APACHE_DOCUMENT_ROOT}|g" /etc/apache2/sites-available/000-default.conf
        sed -i "s|<Directory /var/www/html>|<Directory ${APACHE_DOCUMENT_ROOT}>|g" /etc/apache2/sites-available/000-default.conf
        log_info "Apache document root updated to $APACHE_DOCUMENT_ROOT"
    fi
    
    log_info "Apache configuration updated"
} 