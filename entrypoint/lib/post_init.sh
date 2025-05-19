#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

# Thực hiện các tác vụ hậu xử lý sau khi cài đặt Moodle
post_init_tasks() {
    log_info "Running post-initialization tasks"
    
    # Thiết lập quyền truy cập cho file Moodle
    set_moodle_permissions
    
    # Tạo file .htaccess
    create_htaccess
    
    # Kiểm tra cấu hình Apache trước khi khởi động
    check_apache_config
    
    log_info "Post-initialization tasks completed"
}

# Thiết lập quyền truy cập cho các file Moodle
set_moodle_permissions() {
    log_info "Setting proper permissions for Moodle files"
    
    # Thiết lập quyền truy cập cho thư mục Moodle
    chown -R moodleuser:moodleuser /var/www/html
    
    # Thiết lập quyền truy cập cho thư mục dữ liệu Moodle
    if [ -d "$MOODLE_DATAROOT" ]; then
        chown -R moodleuser:moodleuser "$MOODLE_DATAROOT"
        chmod -R 755 "$MOODLE_DATAROOT"
        log_info "Set permissions for Moodle data directory: $MOODLE_DATAROOT"
    fi
    
    # Thiết lập quyền truy cập cho thư mục cache
    if [ -d "/var/www/html/cache" ]; then
        chmod -R 755 /var/www/html/cache
        log_info "Set permissions for Moodle cache directory"
    fi
    
    # Thiết lập quyền truy cập cho thư mục temporary
    if [ -d "/var/www/html/temp" ]; then
        chmod -R 755 /var/www/html/temp
        log_info "Set permissions for Moodle temp directory"
    fi
    
    log_info "Moodle file permissions set"
}

# Xác minh cài đặt Moodle một cách chi tiết
verify_moodle_installation() {
    log_info "Verifying Moodle installation (detailed)"
    
    # Mảng để lưu lỗi
    local errors=()
    
    # 1. Kiểm tra file config.php
    log_info "1. Checking Moodle config.php file"
    if [ ! -f "/var/www/html/config.php" ]; then
        log_warn "Moodle config.php not found"
        errors+=("config_file_missing")
    else
        log_info "Moodle config.php exists"
    fi
    
    # 2. Kiểm tra thư mục dữ liệu
    log_info "2. Checking Moodle data directory"
    if [ ! -d "$MOODLE_DATAROOT" ]; then
        log_warn "Moodle data directory not found: $MOODLE_DATAROOT"
        errors+=("data_dir_missing")
    else
        log_info "Moodle data directory exists: $MOODLE_DATAROOT"
    fi
    
    # 3. Kiểm tra quyền truy cập thư mục dữ liệu
    log_info "3. Checking data directory permissions"
    if [ -d "$MOODLE_DATAROOT" ] && [ ! -w "$MOODLE_DATAROOT" ]; then
        log_warn "Moodle data directory is not writable: $MOODLE_DATAROOT"
        errors+=("data_dir_not_writable")
    fi
    
    # 4. Kiểm tra kết nối cơ sở dữ liệu
    log_info "4. Checking database connection"
    if [ -n "$MOODLE_DATABASE_PASSWORD" ]; then
        if ! mysql -h "$MOODLE_DATABASE_HOST" -P "$MOODLE_DATABASE_PORT" \
                    -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" \
                    -e "USE $MOODLE_DATABASE_NAME;" >/dev/null 2>&1; then
            log_warn "Cannot connect to Moodle database"
            errors+=("db_connection_failed")
        else
            log_info "Database connection successful"
            
            # 5. Kiểm tra bảng user
            log_info "5. Checking Moodle database tables"
            if ! mysql -h "$MOODLE_DATABASE_HOST" -P "$MOODLE_DATABASE_PORT" \
                        -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" \
                        -e "SELECT * FROM ${MOODLE_DATABASE_PREFIX}user LIMIT 1;" \
                        "$MOODLE_DATABASE_NAME" >/dev/null 2>&1; then
                log_warn "Moodle user table not found or empty"
                errors+=("user_table_missing")
            else
                # Đếm số lượng người dùng
                local user_count
                user_count=$(mysql -h "$MOODLE_DATABASE_HOST" -P "$MOODLE_DATABASE_PORT" \
                          -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" \
                          -e "SELECT COUNT(*) FROM ${MOODLE_DATABASE_PREFIX}user;" \
                          "$MOODLE_DATABASE_NAME" --skip-column-names 2>/dev/null)
                log_info "Number of users in Moodle: $user_count"
            fi
            
            # 6. Kiểm tra phiên bản Moodle
            if mysql -h "$MOODLE_DATABASE_HOST" -P "$MOODLE_DATABASE_PORT" \
                     -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" \
                     -e "SELECT value FROM ${MOODLE_DATABASE_PREFIX}config WHERE name='version';" \
                     "$MOODLE_DATABASE_NAME" >/dev/null 2>&1; then
                local version
                version=$(mysql -h "$MOODLE_DATABASE_HOST" -P "$MOODLE_DATABASE_PORT" \
                       -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" \
                       -e "SELECT value FROM ${MOODLE_DATABASE_PREFIX}config WHERE name='version';" \
                       "$MOODLE_DATABASE_NAME" --skip-column-names 2>/dev/null)
                log_info "Moodle database version: $version"
            else
                log_warn "Could not determine Moodle version"
                errors+=("version_check_failed")
            fi
        fi
    else
        log_warn "MOODLE_DATABASE_PASSWORD not set, skipping database verification"
        errors+=("db_password_missing")
    fi
    
    # Kiểm tra số lượng lỗi và quyết định kết quả
    if [ ${#errors[@]} -gt 0 ]; then
        log_warn "Moodle installation verification found ${#errors[@]} issues"
        log_info "Issues detected: ${errors[*]}"
        return 1
    fi
    
    log_info "Moodle installation verified successfully"
    return 0
}

# Khởi động dịch vụ cron
start_cron_service() {
    log_info "Starting cron service for Moodle"
    
    # Kiểm tra xem cron đã được cài đặt chưa
    if ! command -v cron >/dev/null 2>&1; then
        log_warn "Cron is not installed, skipping cron service"
        return 1
    fi
    
    # Khởi động dịch vụ cron
    service cron start
    
    log_info "Cron service started"
    return 0
}

# Cung cấp công cụ chẩn đoán cho người dùng
diagnose_moodle() {
    log_info "Running Moodle diagnostics"
    
    # Kiểm tra cài đặt Moodle
    verify_moodle_installation
    
    # Kiểm tra cấu hình SSL
    check_ssl_config
    
    # Kiểm tra cấu hình Apache
    check_apache_config
    
    # Kiểm tra PHP extensions
    check_php_extensions
    
    log_info "Diagnostics completed"
}

# Kiểm tra cấu hình SSL
check_ssl_config() {
    log_info "Checking SSL configuration"
    
    # Kiểm tra module SSL
    if ! apache2ctl -M 2>/dev/null | grep -q ssl_module; then
        log_warn "Apache SSL module is not enabled"
        return 1
    fi
    
    # Kiểm tra file chứng chỉ
    if [ ! -f "/etc/apache2/ssl/moodle.crt" ] || [ ! -f "/etc/apache2/ssl/moodle.key" ]; then
        log_warn "SSL certificate files not found"
        return 1
    fi
    
    # Kiểm tra cấu hình SSL site
    if [ ! -f "/etc/apache2/sites-enabled/default-ssl.conf" ]; then
        log_warn "SSL site not enabled"
        return 1
    fi
    
    log_info "SSL configuration looks good"
    return 0
}

# Kiểm tra PHP extensions
check_php_extensions() {
    log_info "Checking PHP extensions for Moodle"
    
    # Danh sách extensions bắt buộc
    local required_extensions=("mysqli" "curl" "openssl" "gd" "xmlrpc" "soap" "zip" "intl" "mbstring")
    local missing_extensions=()
    
    for ext in "${required_extensions[@]}"; do
        if ! php -m | grep -q -i "$ext"; then
            missing_extensions+=("$ext")
            log_warn "Required PHP extension not found: $ext"
        fi
    done
    
    if [ ${#missing_extensions[@]} -gt 0 ]; then
        log_warn "Missing required PHP extensions: ${missing_extensions[*]}"
        return 1
    fi
    
    log_info "All required PHP extensions are installed"
    return 0
} 