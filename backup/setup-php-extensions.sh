#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

set -e
set -u
set -o pipefail

echo "Installing required PHP extensions for Moodle"

# Install necessary build dependencies
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

# Install required PHP extensions
docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp
docker-php-ext-install -j$(nproc) \
    bcmath \
    exif \
    gd \
    intl \
    ldap \
    mysqli \
    opcache \
    pdo_mysql \
    pdo_pgsql \
    pgsql \
    soap \
    xsl \
    zip

# Install APCu, igbinary, memcached, redis
pecl install apcu igbinary memcached redis
docker-php-ext-enable apcu igbinary memcached redis

# Configure PHP settings for Moodle
cat > /usr/local/etc/php/conf.d/moodle.ini << 'EOF'
; PHP settings for Moodle
memory_limit = 512M
max_execution_time = 600
max_input_vars = 5000
upload_max_filesize = 1G
post_max_size = 1G
session.gc_maxlifetime = 7200
opcache.enable = 1
opcache.enable_cli = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 60
opcache.use_cwd = 1
opcache.validate_timestamps = 1
opcache.save_comments = 1
opcache.enable_file_override = 0
apc.enabled = 1
apc.shm_size = 32M
apc.ttl = 7200
apc.enable_cli = 0

; Enable extensions explicitly
extension=apcu.so
extension=igbinary.so
extension=memcached.so
extension=redis.so
EOF

# Install Microsoft SQL Server extension if needed
if [ "$(uname -m)" = "x86_64" ]; then
    echo "Installing Microsoft SQL Server extension for x86_64 architecture"
    
    # Install dependencies for Microsoft SQL Server extension
    apt-get update
    apt-get install -y --no-install-recommends gnupg
    
    # Add Microsoft repository
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
    curl https://packages.microsoft.com/config/debian/12/prod.list > /etc/apt/sources.list.d/mssql-release.list
    
    apt-get update
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 unixodbc-dev
    
    pecl install sqlsrv pdo_sqlsrv
    docker-php-ext-enable sqlsrv pdo_sqlsrv
else
    echo "Skipping Microsoft SQL Server extension for non-x86_64 architecture"
fi

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "PHP extensions installation completed" 