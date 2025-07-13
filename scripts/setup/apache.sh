#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh
. /scripts/lib/config.sh
. /scripts/lib/filesystem.sh

# Load centralized configuration
load_config

debug "Starting Apache setup script"
debug "Current directory: $(pwd)"
debug "Current user: $(whoami)"

info "Starting Apache setup for Absi Technology..."

debug "Checking if user $WEB_SERVER_DAEMON_USER exists..."
ensure_user_exists "$WEB_SERVER_DAEMON_USER" "$WEB_SERVER_DAEMON_GROUP"
debug "User setup completed with exit code: $?"

debug "Creating /var/log/apache2 directory..."
ensure_dir_exists "/var/log/apache2" "$WEB_SERVER_DAEMON_USER" "$WEB_SERVER_DAEMON_GROUP" "775"
debug "Directory creation completed with exit code: $?"

debug "Creating /var/run/apache2 directory..."
ensure_dir_exists "/var/run/apache2" "$WEB_SERVER_DAEMON_USER" "$WEB_SERVER_DAEMON_GROUP" "775"
debug "Directory creation completed with exit code: $?"

debug "Checking Apache configuration..."
if [ -f "/etc/apache2/apache2.conf" ]; then
    debug "Apache2 configuration file exists"
else
    debug "Apache2 configuration file not found"
fi

debug "Checking Apache modules..."
ls -la /etc/apache2/mods-enabled/ >/dev/null 2>&1 || debug "No enabled modules found"

# Configure Apache with dynamic PHP version
PHP_VERSION="${PHP_VERSION:-8.4}"
info "Configuring Apache for PHP ${PHP_VERSION}..."

# Update Apache main config with dynamic PHP-FPM socket (using centralized config)
if [[ -f "$APACHE_CONFIG_DIR/apache2.conf" ]]; then
    debug "Updating Apache main configuration..."
    sed -i "s|php[0-9]\+\.[0-9]\+-fpm\.sock|php${PHP_VERSION}-fpm.sock|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|localhost|$WEB_SERVER_NAME|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|User .*|User $WEB_SERVER_DAEMON_USER|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|Group .*|Group $WEB_SERVER_DAEMON_GROUP|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|/var/www/html|$MOODLE_DIR|g" "$APACHE_CONFIG_DIR/apache2.conf"
fi

# Update default site config
if [[ -f "$APACHE_SITES_DIR/000-default.conf" ]]; then
    debug "Updating default site configuration..."
    sed -i "s|php[0-9]\+\.[0-9]\+-fpm\.sock|php${PHP_VERSION}-fpm.sock|g" "$APACHE_SITES_DIR/000-default.conf"
    sed -i "s|webmaster@localhost|$WEB_SERVER_ADMIN|g" "$APACHE_SITES_DIR/000-default.conf"
    sed -i "s|localhost|$WEB_SERVER_NAME|g" "$APACHE_SITES_DIR/000-default.conf"
    sed -i "s|/var/www/html|$MOODLE_DIR|g" "$APACHE_SITES_DIR/000-default.conf"
fi

# Update SSL site config
if [[ -f "$APACHE_SITES_DIR/000-default-ssl.conf" ]]; then
    debug "Updating SSL site configuration..."
    sed -i "s|php[0-9]\+\.[0-9]\+-fpm\.sock|php${PHP_VERSION}-fpm.sock|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
    sed -i "s|localhost|$WEB_SERVER_NAME|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
    sed -i "s|/etc/ssl/certs/localhost\.crt|$SSL_CERT_FILE|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
    sed -i "s|/etc/ssl/private/localhost\.key|$SSL_KEY_FILE|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
    sed -i "s|/var/www/html|$MOODLE_DIR|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
    sed -i "s|/var/www/moodledata|$MOODLE_DATA_DIR|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
fi

info "Apache configuration updated for PHP ${PHP_VERSION}"
info "Apache setup finished."
debug "Apache setup script completed"
