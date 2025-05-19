#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

# Thiết lập môi trường Moodle
setup_moodle_environment() {
    log_info "Setting up Moodle environment"
    
    # Kiểm tra và cài đặt các biến môi trường cần thiết
    setup_environment_variables
    
    # Thiết lập thư mục dữ liệu
    setup_moodle_datadir
    
    log_info "Moodle environment set up successfully"
}

# Thiết lập biến môi trường
setup_environment_variables() {
    log_info "Setting up environment variables"
    
    # Thiết lập biến môi trường mặc định nếu chưa có
    
    # Biến môi trường PHP
    export PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-512M}
    export PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME:-300}
    export PHP_UPLOAD_MAX_FILESIZE=${PHP_UPLOAD_MAX_FILESIZE:-100M}
    export PHP_POST_MAX_SIZE=${PHP_POST_MAX_SIZE:-100M}
    
    # Biến môi trường Moodle
    export MOODLE_DATAROOT=${MOODLE_DATAROOT:-/var/www/moodledata}
    export MOODLE_WWWROOT=${MOODLE_WWWROOT:-https://localhost}
    export MOODLE_DATABASE_TYPE=${MOODLE_DATABASE_TYPE:-mariadb}
    export MOODLE_DATABASE_HOST=${MOODLE_DATABASE_HOST:-db}
    export MOODLE_DATABASE_PORT=${MOODLE_DATABASE_PORT:-3306}
    export MOODLE_DATABASE_NAME=${MOODLE_DATABASE_NAME:-moodle}
    export MOODLE_DATABASE_USER=${MOODLE_DATABASE_USER:-moodle}
    export MOODLE_DATABASE_PREFIX=${MOODLE_DATABASE_PREFIX:-mdl_}
    export MOODLE_ADMIN_USER=${MOODLE_ADMIN_USER:-admin}
    export MOODLE_SITE_NAME=${MOODLE_SITE_NAME:-"Moodle LMS"}
    export MOODLE_SITE_FULLNAME=${MOODLE_SITE_FULLNAME:-"Moodle Learning Management System"}
    export MOODLE_SITE_SHORTNAME=${MOODLE_SITE_SHORTNAME:-"Moodle LMS"}
    export MOODLE_LANG=${MOODLE_LANG:-en}
    export MOODLE_REVERSEPROXY=${MOODLE_REVERSEPROXY:-false}
    export MOODLE_SSLPROXY=${MOODLE_SSLPROXY:-false}
    
    # Thiết lập biến môi trường Apache
    export APACHE_LOG_DIR=${APACHE_LOG_DIR:-/var/www/logs/apache2}
    
    log_info "Environment variables configured"
}

# Thiết lập thư mục dữ liệu Moodle
setup_moodle_datadir() {
    log_info "Setting up Moodle data directory: $MOODLE_DATAROOT"
    
    # Tạo thư mục dữ liệu nếu chưa tồn tại
    if [ ! -d "$MOODLE_DATAROOT" ]; then
        mkdir -p "$MOODLE_DATAROOT"
        log_info "Created Moodle data directory: $MOODLE_DATAROOT"
    fi
    
    # Thiết lập quyền truy cập
    chown -R moodleuser:moodleuser "$MOODLE_DATAROOT"
    chmod -R 755 "$MOODLE_DATAROOT"
    
    log_info "Moodle data directory set up successfully"
}

# Thiết lập và cài đặt PHP extensions cần thiết cho Moodle
setup_php_extensions() {
    log_info "Setting up PHP extensions for Moodle"
    
    local required_extensions=(
        mysqli pdo pdo_mysql gd intl soap xsl zip
        opcache exif bcmath calendar
    )
    
    local missing_exts=()
    
    # Kiểm tra các extension đã được cài đặt
    for ext in "${required_extensions[@]}"; do
        if ! php -m | grep -q -i "$ext"; then
            missing_exts+=("$ext")
        fi
    done
    
    if [ ${#missing_exts[@]} -eq 0 ]; then
        log_info "All required PHP extensions are already installed"
        return 0
    fi
    
    log_info "Missing PHP extensions: ${missing_exts[*]}"
    log_info "Installing missing PHP extensions"
    
    # Cài đặt các gói phụ thuộc cần thiết
    apt-get update
    apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libldap2-dev \
        libmariadb-dev \
        libmemcached-dev \
        libpng-dev \
        libpq-dev \
        libwebp-dev \
        libxml2-dev \
        libxslt1-dev \
        libzip-dev \
        unixodbc-dev \
        zlib1g-dev
    
    # Cài đặt GD
    if [[ " ${missing_exts[*]} " =~ " gd " ]]; then
        log_info "Configuring and installing GD extension"
        docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp
        docker-php-ext-install -j$(nproc) gd
    fi
    
    # Cài đặt các extension còn lại
    for ext in "${missing_exts[@]}"; do
        if [ "$ext" != "gd" ]; then
            log_info "Installing PHP extension: $ext"
            docker-php-ext-install -j$(nproc) "$ext" || log_warn "Failed to install $ext"
        fi
    done
    
    # Cài đặt extensions từ PECL
    if ! php -m | grep -q -i "memcached"; then
        log_info "Installing memcached extension"
        pecl install memcached
        docker-php-ext-enable memcached
    fi
    
    if ! php -m | grep -q -i "redis"; then
        log_info "Installing redis extension"
        pecl install redis
        docker-php-ext-enable redis
    fi
    
    # Dọn dẹp
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    
    log_info "PHP extensions setup completed"
}

# Enable required Apache modules
enable_apache_modules() {
    log_info "Enabling required Apache modules"
    
    # Enable required modules
    a2enmod rewrite
    a2enmod expires
    a2enmod headers
    
    # Enable SSL if needed
    if [ "$MOODLE_SSLPROXY" = "true" ]; then
        a2enmod ssl
        log_info "SSL module enabled"
    fi
    
    log_info "Apache modules enabled"
}

# Configure Moodle config.php
configure_moodle_config() {
    local config_file="/var/www/html/config.php"
    
    # Skip if config.php already exists and we're not forcing reconfiguration
    if [ -f "$config_file" ] && [ -z "$MOODLE_RECONFIGURE" ]; then
        log_info "Moodle config.php already exists, skipping configuration"
        return 0
    fi
    
    # Check if database password is set
    if [ -z "$MOODLE_DATABASE_PASSWORD" ]; then
        log_warn "MOODLE_DATABASE_PASSWORD not set, skipping Moodle config.php generation"
        return 0
    fi
    
    log_info "Configuring Moodle config.php"
    
    # Create config.php file
    cat > "$config_file" << EOF
<?php  // Moodle configuration file

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = '${MOODLE_DATABASE_TYPE}';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = '${MOODLE_DATABASE_HOST}';
\$CFG->dbname    = '${MOODLE_DATABASE_NAME}';
\$CFG->dbuser    = '${MOODLE_DATABASE_USER}';
\$CFG->dbpass    = '${MOODLE_DATABASE_PASSWORD}';
\$CFG->prefix    = '${MOODLE_DATABASE_PREFIX}';
\$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => ${MOODLE_DATABASE_PORT},
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot   = '${MOODLE_WWWROOT}';
\$CFG->dataroot  = '${MOODLE_DATAROOT}';
\$CFG->admin     = 'admin';

\$CFG->directorypermissions = 0777;
\$CFG->reverseproxy = ${MOODLE_REVERSEPROXY};
\$CFG->sslproxy = ${MOODLE_SSLPROXY};

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF
    
    # Set proper permissions
    chown moodleuser:moodleuser "$config_file"
    chmod 644 "$config_file"
    
    log_info "Moodle config.php configured"
}

# Post-initialization tasks
post_init_tasks() {
    log_info "Running post-initialization tasks"
    
    # Set proper permissions for Moodle files
    chown -R moodleuser:moodleuser /var/www/html
    
    # Fix permissions for Apache logs
    if [ -d "/var/www/logs/apache2" ]; then
        # Ensure log files exist
        touch /var/www/logs/apache2/access.log /var/www/logs/apache2/error.log
        # Set permissions
        chmod -R 777 /var/www/logs
        chown -R moodleuser:moodleuser /var/www/logs
        # Double check specific log files
        chmod 777 /var/www/logs/apache2/access.log /var/www/logs/apache2/error.log
        log_info "Set permissions for Apache logs"
    fi
    
    # Create .htaccess file if it doesn't exist
    if [ ! -f "/var/www/html/.htaccess" ]; then
        log_info "Creating default .htaccess file"
        cat > "/var/www/html/.htaccess" << 'EOF'
# Moodle .htaccess
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
        chown moodleuser:moodleuser "/var/www/html/.htaccess"
    fi
    
    log_info "Post-initialization tasks completed"
} 