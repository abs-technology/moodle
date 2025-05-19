#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

set -eo pipefail

# Function to log messages
log_info() {
    echo "[SSL-SETUP] [INFO] $1"
}

log_error() {
    echo "[SSL-SETUP] [ERROR] $1" >&2
}

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Install SSL modules for Apache
install_ssl_modules() {
    log_info "Installing Apache SSL modules"
    apt-get update -y
    apt-get install -y --no-install-recommends ssl-cert
    a2enmod ssl
    a2enmod headers
}

# Generate self-signed certificate
generate_ssl_cert() {
    local cert_file="/etc/ssl/certs/moodle-cert.pem"
    local key_file="/etc/ssl/private/moodle-key.pem"
    
    # Create directories if they don't exist
    mkdir -p /etc/ssl/certs
    mkdir -p /etc/ssl/private
    
    # Always generate new certificate to ensure it exists
    log_info "Generating self-signed SSL certificate"
    
    # Generate self-signed certificate
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "$key_file" \
        -out "$cert_file" \
        -subj "/C=VN/ST=Hanoi/L=Hanoi/O=ABS Technology/OU=Moodle/CN=moodle.local"
    
    # Set proper permissions
    chmod 644 "$cert_file"
    chmod 600 "$key_file"
    
    # Verify files exist and have proper size
    if [ ! -s "$cert_file" ] || [ ! -s "$key_file" ]; then
        log_error "Failed to generate SSL certificate files or files are empty"
        return 1
    fi
    
    log_info "SSL certificate generated successfully"
}

# Enable SSL configuration for Apache
enable_ssl_config() {
    local default_ssl_conf="/etc/apache2/sites-available/default-ssl.conf"
    
    log_info "Enabling SSL configuration for Apache"
    
    # Always create a new configuration
    if [ -f "/var/www/html/config/apache-ssl.conf" ]; then
        cp /var/www/html/config/apache-ssl.conf "$default_ssl_conf"
        log_info "Copied SSL configuration from template"
    else
        # Create a basic SSL configuration
        cat > "$default_ssl_conf" << 'EOF'
<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
        
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        
        SSLEngine on
        SSLCertificateFile /etc/ssl/certs/moodle-cert.pem
        SSLCertificateKeyFile /etc/ssl/private/moodle-key.pem
        
        <FilesMatch "\.(cgi|shtml|phtml|php)$">
            SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
            SSLOptions +StdEnvVars
        </Directory>
        
        <Directory /var/www/html>
            Options -Indexes +FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>
    </VirtualHost>
</IfModule>
EOF
        log_info "Created default SSL configuration"
    fi
    
    # Verify SSL config exists
    if [ ! -f "$default_ssl_conf" ]; then
        log_error "SSL configuration file does not exist after creation attempt"
        return 1
    fi
    
    # Enable SSL site
    a2ensite default-ssl
    
    log_info "SSL configuration enabled"
}

# Main function
main() {
    log_info "Starting SSL setup"
    
    # Install SSL modules
    install_ssl_modules
    
    # Generate SSL certificate
    generate_ssl_cert
    
    # Enable SSL configuration
    enable_ssl_config
    
    # Restart Apache
    if command -v apache2ctl &> /dev/null; then
        log_info "Testing Apache configuration"
        apache2ctl configtest
        if [ $? -eq 0 ]; then
            log_info "Apache configuration is valid, restarting service"
            service apache2 restart || log_error "Failed to restart Apache"
        else
            log_error "Apache configuration test failed, please check configuration"
            # Display the certificates for debugging
            ls -la /etc/ssl/certs/moodle-cert.pem /etc/ssl/private/moodle-key.pem || true
        fi
    fi
    
    log_info "SSL setup completed successfully"
}

# Run main function
main 