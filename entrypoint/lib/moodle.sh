#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

# Kiểm tra và cài đặt Moodle nếu chưa được cài đặt
check_and_install_moodle() {
    # Kiểm tra xem có cần tự động cài đặt không
    if [ "$MOODLE_AUTO_INSTALL" != "true" ]; then
        log_info "Tự động cài đặt Moodle đã bị tắt (MOODLE_AUTO_INSTALL=false)"
        return 0
    fi
    
    log_info "Kiểm tra và cài đặt Moodle nếu cần"
    
    # Kiểm tra xem config.php đã tồn tại chưa
    if [ -f "/var/www/html/config.php" ]; then
        log_info "File config.php đã tồn tại, bỏ qua quá trình cài đặt"
        return 0
    fi
    
    # Kiểm tra xem có đủ thông tin để cài đặt không
    if [ -z "$MOODLE_DATABASE_PASSWORD" ]; then
        log_warn "MOODLE_DATABASE_PASSWORD không được đặt, không thể cài đặt tự động"
        return 1
    fi
    
    log_info "Tiến hành cài đặt Moodle tự động"
    
    # Tạo thư mục dữ liệu nếu chưa tồn tại
    if [ ! -d "$MOODLE_DATAROOT" ]; then
        mkdir -p "$MOODLE_DATAROOT"
        chown -R moodleuser:moodleuser "$MOODLE_DATAROOT"
        chmod -R 777 "$MOODLE_DATAROOT"
        log_info "Đã tạo thư mục dữ liệu Moodle: $MOODLE_DATAROOT"
    fi
    
    # Kiểm tra xem Moodle đã được cài đặt trong database chưa
    if mysql -h "$MOODLE_DATABASE_HOST" -P "$MOODLE_DATABASE_PORT" \
             -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" \
             -e "USE $MOODLE_DATABASE_NAME; SELECT * FROM ${MOODLE_DATABASE_PREFIX}user LIMIT 1;" 2>/dev/null; then
        log_info "Moodle đã được cài đặt trong cơ sở dữ liệu, chỉ cần tạo config.php"
        configure_moodle_config
        return 0
    fi
    
    # Cài đặt Moodle thông qua hàm install_moodle có sẵn
    install_moodle
    return $?
}

# Install Moodle if not already installed
install_moodle() {
    # Skip installation if specified
    if [ -n "$MOODLE_SKIP_INSTALL" ]; then
        log_info "Skipping Moodle installation as requested by MOODLE_SKIP_INSTALL"
        return 0
    fi
    
    # Check if Moodle is already installed
    if [ -f "/var/www/html/config.php" ] && [ -z "$MOODLE_RECONFIGURE" ]; then
        log_info "Moodle config.php already exists, skipping installation"
        
        if [ "$MOODLE_RECONFIGURE" = "true" ]; then
            log_info "MOODLE_RECONFIGURE is set, will reinstall Moodle"
        else
            # Check if we should upgrade
            if is_moodle_db_installed; then
                log_info "Moodle database already installed, checking for upgrades"
                upgrade_moodle
            fi
            return 0
        fi
    fi
    
    # Check if required variables are set
    if [ -z "$MOODLE_DATABASE_PASSWORD" ]; then
        log_warn "MOODLE_DATABASE_PASSWORD not set, skipping Moodle installation"
        return 0
    fi
    
    # Kiểm tra admin password
    if [ -z "$MOODLE_ADMIN_PASSWORD" ]; then
        log_warn "MOODLE_ADMIN_PASSWORD không được đặt, sử dụng mật khẩu mặc định"
        MOODLE_ADMIN_PASSWORD="Admin123!"
    fi
    
    # Kiểm tra admin email
    if [ -z "$MOODLE_ADMIN_EMAIL" ]; then
        log_warn "MOODLE_ADMIN_EMAIL không được đặt, sử dụng địa chỉ email mặc định"
        MOODLE_ADMIN_EMAIL="admin@example.com"
    fi
    
    log_info "Starting Moodle installation"
    log_info "- Database: $MOODLE_DATABASE_TYPE://$MOODLE_DATABASE_USER@$MOODLE_DATABASE_HOST:$MOODLE_DATABASE_PORT/$MOODLE_DATABASE_NAME"
    log_info "- Site: $MOODLE_SITE_FULLNAME ($MOODLE_SITE_SHORTNAME)"
    log_info "- Language: $MOODLE_LANG"
    log_info "- Web root: $MOODLE_WWWROOT"
    log_info "- Data root: $MOODLE_DATAROOT"
    
    # Validate database type
    if [ "$MOODLE_DATABASE_TYPE" != "mysqli" ] && [ "$MOODLE_DATABASE_TYPE" != "mariadb" ]; then
        log_warn "Invalid database type: $MOODLE_DATABASE_TYPE. Using mariadb as default."
        export MOODLE_DATABASE_TYPE="mariadb"
    fi
    
    log_info "Using database type: $MOODLE_DATABASE_TYPE"
    
    # Configure Moodle
    configure_moodle_config
    
    # Run installation command if database is empty
    if ! is_moodle_db_installed; then
        log_info "Installing Moodle database"
        
        # Check data directory permissions
        if [ ! -d "$MOODLE_DATAROOT" ]; then
            log_info "Creating Moodle data directory: $MOODLE_DATAROOT"
            mkdir -p "$MOODLE_DATAROOT"
        fi
        
        # Set permissions
        log_info "Setting permissions for Moodle data directory"
        chown -R moodleuser:moodleuser "$MOODLE_DATAROOT"
        chmod -R 755 "$MOODLE_DATAROOT"
        
        # Create installation command
        local install_cmd="php /var/www/html/admin/cli/install.php"
        install_cmd="$install_cmd --lang=$MOODLE_LANG"
        install_cmd="$install_cmd --wwwroot=$MOODLE_WWWROOT"
        install_cmd="$install_cmd --dataroot=$MOODLE_DATAROOT"
        install_cmd="$install_cmd --dbtype=$MOODLE_DATABASE_TYPE"
        install_cmd="$install_cmd --dbhost=$MOODLE_DATABASE_HOST"
        install_cmd="$install_cmd --dbname=$MOODLE_DATABASE_NAME"
        install_cmd="$install_cmd --dbuser=$MOODLE_DATABASE_USER"
        install_cmd="$install_cmd --dbpass=$MOODLE_DATABASE_PASSWORD"
        install_cmd="$install_cmd --dbport=$MOODLE_DATABASE_PORT"
        install_cmd="$install_cmd --prefix=$MOODLE_DATABASE_PREFIX"
        install_cmd="$install_cmd --fullname=\"$MOODLE_SITE_FULLNAME\""
        install_cmd="$install_cmd --shortname=\"$MOODLE_SITE_SHORTNAME\""
        install_cmd="$install_cmd --adminuser=$MOODLE_ADMIN_USER"
        install_cmd="$install_cmd --adminpass=$MOODLE_ADMIN_PASSWORD"
        install_cmd="$install_cmd --adminemail=$MOODLE_ADMIN_EMAIL"
        install_cmd="$install_cmd --non-interactive"
        install_cmd="$install_cmd --agree-license"
        install_cmd="$install_cmd --allow-unstable"
        
        log_info "Running Moodle installation command"
        
        # Run installation as moodleuser
        if su - moodleuser -s /bin/bash -c "$install_cmd"; then
            log_info "Moodle database installation completed successfully"
            
            # Run post-installation tasks
            log_info "Setting up cron job for Moodle"
            setup_moodle_cron
            
            # Purge Moodle cache
            log_info "Purging Moodle cache"
            purge_moodle_cache
            
            log_info "Moodle installation completed successfully"
            log_info "You can now access Moodle at $MOODLE_WWWROOT"
            log_info "Admin username: $MOODLE_ADMIN_USER"
            log_info "Admin password: $MOODLE_ADMIN_PASSWORD"
        else
            log_error "Moodle installation failed. Check the logs for more information."
            return 1
        fi
    else
        log_info "Moodle database already installed, skipping database setup"
        
        # Check if we need to upgrade
        log_info "Checking for Moodle upgrades"
        upgrade_moodle
    fi
    
    log_info "Moodle setup completed"
    return 0
}

# Check if Moodle database is already installed
is_moodle_db_installed() {
    local result=0
    
    # Check if database password is set
    if [ -z "$MOODLE_DATABASE_PASSWORD" ]; then
        log_warn "MOODLE_DATABASE_PASSWORD not set, cannot check if Moodle database is installed"
        return 1
    fi
    
    log_info "Checking if Moodle database is already installed on $MOODLE_DATABASE_HOST:$MOODLE_DATABASE_PORT..."
    
    # Check connectivity to database first
    if ! mysql -h "$MOODLE_DATABASE_HOST" -P "$MOODLE_DATABASE_PORT" \
                -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" \
                -e "SELECT 1;" --skip-column-names &>/dev/null; then
        log_warn "Cannot connect to database server at $MOODLE_DATABASE_HOST:$MOODLE_DATABASE_PORT"
        return 1
    fi
    
    # Check if database exists
    if ! mysql -h "$MOODLE_DATABASE_HOST" -P "$MOODLE_DATABASE_PORT" \
                -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" \
                -e "USE $MOODLE_DATABASE_NAME;" --skip-column-names &>/dev/null; then
        log_warn "Database $MOODLE_DATABASE_NAME does not exist"
        return 1
    fi
    
    # Try to connect to database and check if users table exists
    if [ "$MOODLE_DATABASE_TYPE" = "mysqli" ]; then
        # Use MySQL client
        log_info "Using MySQL client to check database"
        result=$(mysql -h "$MOODLE_DATABASE_HOST" -P "$MOODLE_DATABASE_PORT" \
                    -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" \
                    -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$MOODLE_DATABASE_NAME' AND table_name = '${MOODLE_DATABASE_PREFIX}user';" \
                    --skip-column-names 2>/dev/null || echo "0")
    else
        # Try MariaDB client first, fallback to MySQL client
        log_info "Using MariaDB client to check database"
        result=$(mariadb -h "$MOODLE_DATABASE_HOST" -P "$MOODLE_DATABASE_PORT" \
                    -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" \
                    -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$MOODLE_DATABASE_NAME' AND table_name = '${MOODLE_DATABASE_PREFIX}user';" \
                    --skip-column-names 2>/dev/null || \
                 mysql -h "$MOODLE_DATABASE_HOST" -P "$MOODLE_DATABASE_PORT" \
                    -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" \
                    -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$MOODLE_DATABASE_NAME' AND table_name = '${MOODLE_DATABASE_PREFIX}user';" \
                    --skip-column-names 2>/dev/null || echo "0")
    fi
    
    if [ "$result" -gt "0" ]; then
        log_info "Found Moodle tables in database $MOODLE_DATABASE_NAME, installation detected"
        return 0
    else
        log_info "No Moodle tables found in database $MOODLE_DATABASE_NAME, fresh installation required"
        return 1
    fi
}

# Kiểm tra xem Moodle đã được cài đặt chưa (kiểm tra cả file và database)
is_moodle_installed() {
    # Kiểm tra file config.php
    if [ ! -f "/var/www/html/config.php" ]; then
        return 1
    fi
    
    # Kiểm tra cơ sở dữ liệu nếu có thông tin đăng nhập
    if [ -n "$MOODLE_DATABASE_PASSWORD" ]; then
        if ! mysql -h "$MOODLE_DATABASE_HOST" -P "$MOODLE_DATABASE_PORT" \
                -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" \
                -e "USE $MOODLE_DATABASE_NAME; SELECT * FROM ${MOODLE_DATABASE_PREFIX}user LIMIT 1;" >/dev/null 2>&1; then
            return 1
        fi
    fi
    
    return 0
}

# Upgrade Moodle if needed
upgrade_moodle() {
    # Skip upgrade if installation is skipped
    if [ -n "$MOODLE_SKIP_INSTALL" ]; then
        log_info "Skipping Moodle upgrade as installation is skipped"
        return 0
    fi
    
    # Check if Moodle is installed
    if [ ! -f "/var/www/html/config.php" ]; then
        log_info "Moodle not installed, skipping upgrade"
        return 0
    fi
    
    # Check if database password is set
    if [ -z "$MOODLE_DATABASE_PASSWORD" ]; then
        log_warn "MOODLE_DATABASE_PASSWORD not set, skipping Moodle upgrade"
        return 0
    fi
    
    log_info "Checking for Moodle upgrades"
    
    # Run upgrade command
    su - moodleuser -s /bin/bash -c "php /var/www/html/admin/cli/upgrade.php --non-interactive --allow-unstable"
    
    log_info "Moodle upgrade completed"
}

# Set up cron job for Moodle
setup_moodle_cron() {
    log_info "Setting up Moodle cron job"
    
    # Create cron file
    cat > /etc/cron.d/moodle << EOF
# Moodle cron job
*/1 * * * * moodleuser /usr/local/bin/php /var/www/html/admin/cli/cron.php > /dev/null 2>&1
EOF
    
    # Set proper permissions
    chmod 644 /etc/cron.d/moodle
    
    log_info "Moodle cron job set up"
}

# Purge Moodle cache
purge_moodle_cache() {
    log_info "Purging Moodle cache"
    
    # Run purge command
    su - moodleuser -s /bin/bash -c "php /var/www/html/admin/cli/purge_caches.php"
    
    log_info "Moodle cache purged"
} 