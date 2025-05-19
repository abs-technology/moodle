#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

# Setup Apache for Moodle
setup_apache() {
    log_info "Setting up Apache for Moodle"
    
    # Thiết lập quyền truy cập cho thư mục Apache runtime
    setup_apache_runtime_dirs
    
    # Thiết lập thư mục logs
    setup_apache_logs
    
    # Cấu hình các module Apache cần thiết
    log_info "Enabling required Apache modules"
    a2enmod rewrite
    a2enmod expires
    a2enmod headers
    
    log_info "Apache setup completed"
}

# Setup Apache runtime directories
setup_apache_runtime_dirs() {
    log_info "Setting up Apache runtime directories"
    
    # Tạo và cấu hình thư mục /var/run/apache2
    mkdir -p /var/run/apache2
    chmod -R 755 /var/run/apache2
    chown -R moodleuser:moodleuser /var/run/apache2
    
    # Tạo và cấu hình thư mục /var/lock/apache2
    mkdir -p /var/lock/apache2
    chmod -R 755 /var/lock/apache2
    chown -R moodleuser:moodleuser /var/lock/apache2
    
    # Xóa PID file cũ nếu có
    if [ -f "/var/run/apache2/apache2.pid" ]; then
        rm -f /var/run/apache2/apache2.pid
        log_info "Removed old Apache PID file"
    fi
    
    log_info "Apache runtime directories set up successfully"
}

# Setup Apache logs
setup_apache_logs() {
    log_info "Setting up Apache logs"
    
    # Tạo thư mục logs nếu chưa tồn tại
    if [ ! -d "/var/www/logs/apache2" ]; then
        # Đảm bảo thư mục tồn tại
        mkdir -p /var/www/logs/apache2
        log_info "Created Apache logs directory"
    fi
    
    # Tạo các file log và thiết lập quyền
    touch /var/www/logs/apache2/access.log /var/www/logs/apache2/error.log
    chmod -R 777 /var/www/logs
    chown -R moodleuser:moodleuser /var/www/logs
    chmod 777 /var/www/logs/apache2/access.log /var/www/logs/apache2/error.log
    
    # Đặt APACHE_LOG_DIR trong môi trường
    export APACHE_LOG_DIR=/var/www/logs/apache2
    
    log_info "Apache logs set up successfully"
}

# Kiểm tra và hiển thị thông tin về cấu hình Apache
check_apache_config() {
    log_info "Checking Apache configuration"
    
    # Kiểm tra cấu hình Apache
    if ! apache2ctl configtest > /dev/null 2>&1; then
        log_warn "Apache configuration test failed"
        apache2ctl configtest
        return 1
    fi
    
    log_info "Apache configuration test passed"
    
    # Hiển thị thông tin về thư mục Apache runtime
    log_info "Apache runtime directories:"
    ls -la /var/run/apache2 /var/lock/apache2
    
    # Hiển thị thông tin về thư mục logs
    log_info "Apache logs directories:"
    ls -la /var/www/logs/apache2
    
    return 0
}

# Tạo .htaccess file cho Moodle
create_htaccess() {
    log_info "Creating .htaccess file for Moodle"
    
    # Kiểm tra xem .htaccess đã tồn tại chưa
    if [ -f "/var/www/html/.htaccess" ]; then
        log_info ".htaccess file already exists"
        return 0
    fi
    
    # Kiểm tra template từ các vị trí khác nhau
    if [ -f "/var/www/html/config/htaccess.template" ]; then
        log_info "Creating .htaccess file from template in config directory"
        cp "/var/www/html/config/htaccess.template" "/var/www/html/.htaccess"
    elif [ -f "/var/www/html/htaccess.template" ]; then
        log_info "Creating .htaccess file from template in root directory"
        cp "/var/www/html/htaccess.template" "/var/www/html/.htaccess"
    else
        log_info "Creating default .htaccess file"
        cat > "/var/www/html/.htaccess" << 'EOF'
# Moodle .htaccess - Default
<IfModule mod_rewrite.c>
    RewriteEngine on
    RewriteRule "(^|/)\." - [F]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^(.*)$ index.php?q=$1 [L,QSA]
</IfModule>

<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresDefault "access plus 1 week"
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType application/x-javascript "access plus 1 month"
    ExpiresByType image/gif "access plus 1 month"
    ExpiresByType image/jpeg "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresByType image/webp "access plus 1 month"
    ExpiresByType image/svg+xml "access plus 1 month"
    ExpiresByType image/x-icon "access plus 1 year"
    ExpiresByType font/ttf "access plus 1 year"
    ExpiresByType font/otf "access plus 1 year"
    ExpiresByType font/woff "access plus 1 year"
    ExpiresByType font/woff2 "access plus 1 year"
</IfModule>

<IfModule mod_headers.c>
    Header set X-Content-Type-Options "nosniff"
    Header set X-XSS-Protection "1; mode=block"
    Header set X-Frame-Options "SAMEORIGIN"
</IfModule>

# Disable directory browsing
Options -Indexes
EOF
    fi
    
    # Thiết lập quyền cho file .htaccess
    chown moodleuser:moodleuser "/var/www/html/.htaccess"
    chmod 644 "/var/www/html/.htaccess"
    
    log_info ".htaccess file created successfully"
} 