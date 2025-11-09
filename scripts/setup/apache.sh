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

# Update Apache main config with environment variables
if [[ -f "$APACHE_CONFIG_DIR/apache2.conf" ]]; then
    debug "Updating Apache main configuration with environment variables..."
    
    # Replace template placeholders with actual values
    sed -i "s|{{WEB_SERVER_NAME}}|${WEB_SERVER_NAME}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{APACHE_HTTP_PORT}}|${APACHE_HTTP_PORT}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{APACHE_HTTPS_PORT}}|${APACHE_HTTPS_PORT}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{PHP_FPM_SOCKET}}|${PHP_FPM_SOCKET}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{APACHE_TIMEOUT}}|${APACHE_TIMEOUT}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{APACHE_KEEPALIVE}}|${APACHE_KEEPALIVE}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{APACHE_MAX_KEEPALIVE_REQUESTS}}|${APACHE_MAX_KEEPALIVE_REQUESTS}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{APACHE_KEEPALIVE_TIMEOUT}}|${APACHE_KEEPALIVE_TIMEOUT}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{APACHE_LOG_LEVEL}}|${APACHE_LOG_LEVEL}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    
    # Worker configuration
    sed -i "s|{{WEB_SERVER_DAEMON_USER}}|${WEB_SERVER_DAEMON_USER}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{WEB_SERVER_DAEMON_GROUP}}|${WEB_SERVER_DAEMON_GROUP}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    
    # Document root
    sed -i "s|{{MOODLE_DIR}}|${MOODLE_DIR}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    
    # MPM configuration
    sed -i "s|{{APACHE_START_SERVERS}}|${APACHE_START_SERVERS}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{APACHE_MIN_SPARE_SERVERS}}|${APACHE_MIN_SPARE_SERVERS}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{APACHE_MAX_SPARE_SERVERS}}|${APACHE_MAX_SPARE_SERVERS}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{APACHE_MAX_REQUEST_WORKERS}}|${APACHE_MAX_REQUEST_WORKERS}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{APACHE_MAX_CONNECTIONS_PER_CHILD}}|${APACHE_MAX_CONNECTIONS_PER_CHILD}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    sed -i "s|{{APACHE_SERVER_LIMIT}}|${APACHE_SERVER_LIMIT}|g" "$APACHE_CONFIG_DIR/apache2.conf"
    
    # Configure log format based on proxy mode
    if [[ "$MOODLE_REVERSEPROXY" == "yes" ]]; then
        LOG_FORMAT="combined_lb"
        debug "Using load balancer log format"
    else
        LOG_FORMAT="combined"
        debug "Using standard log format"
    fi
    sed -i "s|{{LOG_FORMAT}}|${LOG_FORMAT}|g" "$APACHE_CONFIG_DIR/apache2.conf"
fi

# Configure site based on load balancing settings (Option B logic)
info "Configuring Apache site based on proxy settings..."
debug "MOODLE_REVERSEPROXY: ${MOODLE_REVERSEPROXY}"
debug "MOODLE_SSLPROXY: ${MOODLE_SSLPROXY}"

if [[ "$MOODLE_REVERSEPROXY" == "yes" ]]; then
    info "Load balancer mode enabled - using load balancer configuration"
    
    # Use load balancer template
    if [[ -f "$APACHE_SITES_DIR/000-default-lb.conf" ]]; then
        cp "$APACHE_SITES_DIR/000-default-lb.conf" "$APACHE_SITES_DIR/000-default.conf"
        debug "Copied load balancer template to 000-default.conf"
    else
        warn "Load balancer template not found, using original config"
    fi
    
    # Configure SSL proxy handling based on MOODLE_SSLPROXY
    if [[ "$MOODLE_SSLPROXY" == "yes" ]]; then
        info "SSL proxy mode enabled - configuring HTTPS termination handling"
        SSL_PROXY_HEADERS='SetEnvIf X-Forwarded-Proto "https" HTTPS=on'
        SSL_PROXY_REWRITE_RULES='# Handle HTTPS termination at load balancer
        RewriteCond %{HTTP:X-Forwarded-Proto} =https
        RewriteRule ^(.*)$ - [E=HTTPS:on]
        
        # Set HTTPS environment variable for proper Moodle detection
        RewriteCond %{HTTP:X-Forwarded-Proto} =https
        RewriteRule ^(.*)$ - [E=HTTPS:on,E=SERVER_PORT:443]'
    else
        info "SSL proxy mode disabled - no HTTPS termination handling"
        SSL_PROXY_HEADERS='# SSL proxy disabled'
        SSL_PROXY_REWRITE_RULES='# SSL proxy disabled - no HTTPS termination rules'
    fi
    
else
    info "Load balancer mode disabled - using direct connection configuration"
    
    # Use direct connection template
    if [[ -f "$APACHE_SITES_DIR/000-default-direct.conf" ]]; then
        cp "$APACHE_SITES_DIR/000-default-direct.conf" "$APACHE_SITES_DIR/000-default.conf"
        debug "Copied direct connection template to 000-default.conf"
    else
        warn "Direct connection template not found, using original config"
    fi
    
    # No SSL proxy variables needed for direct mode
    SSL_PROXY_HEADERS='# Direct connection mode - no proxy headers'
    SSL_PROXY_REWRITE_RULES='# Direct connection mode - no proxy rewrite rules'
fi

# Update the selected configuration with environment variables
if [[ -f "$APACHE_SITES_DIR/000-default.conf" ]]; then
    debug "Updating site configuration with environment variables..."
    sed -i "s|{{APACHE_HTTP_PORT}}|${APACHE_HTTP_PORT}|g" "$APACHE_SITES_DIR/000-default.conf"
    sed -i "s|{{WEB_SERVER_ADMIN}}|${WEB_SERVER_ADMIN}|g" "$APACHE_SITES_DIR/000-default.conf"
    sed -i "s|{{MOODLE_DIR}}|${MOODLE_DIR}|g" "$APACHE_SITES_DIR/000-default.conf"
    sed -i "s|{{PHP_FPM_SOCKET}}|${PHP_FPM_SOCKET}|g" "$APACHE_SITES_DIR/000-default.conf"
    
    # Replace SSL proxy placeholders
    sed -i "s|{{SSL_PROXY_HEADERS}}|${SSL_PROXY_HEADERS}|g" "$APACHE_SITES_DIR/000-default.conf"
    sed -i "s|{{SSL_PROXY_REWRITE_RULES}}|${SSL_PROXY_REWRITE_RULES}|g" "$APACHE_SITES_DIR/000-default.conf"
fi

# Update SSL site config
if [[ -f "$APACHE_SITES_DIR/000-default-ssl.conf" ]]; then
    debug "Updating SSL site configuration..."
    sed -i "s|{{APACHE_HTTPS_PORT}}|${APACHE_HTTPS_PORT}|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
    sed -i "s|{{WEB_SERVER_ADMIN}}|${WEB_SERVER_ADMIN}|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
    sed -i "s|{{MOODLE_DIR}}|${MOODLE_DIR}|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
    sed -i "s|{{SSL_CERT_FILE}}|${SSL_CERT_FILE}|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
    sed -i "s|{{SSL_KEY_FILE}}|${SSL_KEY_FILE}|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
    sed -i "s|{{MOODLE_DATA_DIR}}|${MOODLE_DATA_DIR}|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
    sed -i "s|{{PHP_FPM_SOCKET}}|${PHP_FPM_SOCKET}|g" "$APACHE_SITES_DIR/000-default-ssl.conf"
fi

info "Apache configuration updated for PHP ${PHP_VERSION}"
info "Apache setup finished."
debug "Apache setup script completed"
