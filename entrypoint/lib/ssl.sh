#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

# Setup SSL for Moodle
setup_ssl() {
    log_info "Setting up SSL for Moodle"
    
    # Tạo thư mục SSL 
    log_info "Creating SSL certificate directories"
    mkdir -p /etc/apache2/ssl
    chmod 755 /etc/apache2/ssl
    
    # Tạo chứng chỉ SSL mới
    log_info "Generating SSL certificate"
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "/etc/apache2/ssl/moodle.key" \
        -out "/etc/apache2/ssl/moodle.crt" \
        -subj "/C=VN/ST=Hanoi/L=Hanoi/O=ABS Technology/OU=Moodle/CN=moodle.local"
    
    # Thiết lập quyền
    log_info "Setting permissions on SSL files"
    chmod 644 /etc/apache2/ssl/moodle.crt
    chmod 640 /etc/apache2/ssl/moodle.key
    chown moodleuser:moodleuser /etc/apache2/ssl/moodle.*
    
    # Hiển thị thông tin
    ls -la /etc/apache2/ssl/
    
    # Tạo cấu hình SSL 
    create_ssl_config
    
    # Thêm ServerName vào cấu hình Apache toàn cục
    log_info "Adding ServerName to global Apache configuration"
    echo "ServerName moodle.local" > /etc/apache2/conf-available/servername.conf
    a2enconf servername
    
    # Kích hoạt SSL 
    log_info "Enabling SSL module and site"
    a2enmod ssl
    a2ensite default-ssl
    
    log_info "SSL setup completed"
}

# Create SSL configuration for Apache
create_ssl_config() {
    log_info "Creating Apache SSL configuration"
    cat > /etc/apache2/sites-available/default-ssl.conf << 'EOF'
<VirtualHost *:443>
    ServerAdmin webmaster@localhost
    ServerName moodle.local
    DocumentRoot /var/www/html

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/moodle.crt
    SSLCertificateKeyFile /etc/apache2/ssl/moodle.key

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch "\.(cgi|shtml|phtml|php)$">
        SSLOptions +StdEnvVars
    </FilesMatch>
    
    <Directory /usr/lib/cgi-bin>
        SSLOptions +StdEnvVars
    </Directory>
</VirtualHost>
EOF
}

# Create SSL certificate directly (alternative method)
create_ssl_certificate() {
    local cert_file="/etc/ssl/certs/moodle-cert.pem"
    local key_file="/etc/ssl/private/moodle-key.pem"
    
    log_info "Ensuring SSL directories exist"
    mkdir -p /etc/ssl/certs
    mkdir -p /etc/ssl/private
    
    # Always create a new certificate
    log_info "Creating SSL certificate"
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
      -keyout "$key_file" \
      -out "$cert_file" \
      -subj "/C=VN/ST=Hanoi/L=Hanoi/O=ABS Technology/OU=Moodle/CN=moodle.local"
    
    # Set permissions
    chmod 644 "$cert_file"
    chmod 600 "$key_file"
    chown root:root "$cert_file" "$key_file"
    
    # Verify certificate
    if [ ! -s "$cert_file" ] || [ ! -s "$key_file" ]; then
        log_error "Failed to create SSL certificate. Files do not exist or are empty."
        ls -la "$cert_file" "$key_file" || true
        return 1
    fi
    
    log_info "SSL certificate created successfully"
    log_info "Certificate file: $(ls -la $cert_file)"
    log_info "Private key file: $(ls -la $key_file)"
    return 0
} 