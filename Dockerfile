# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

FROM php:8.2-apache

# Metadata
LABEL maintainer="ABS Technology <info@abs.vn>"
LABEL description="Moodle 5.0 container image with SSL support"
LABEL version="1.0"

# So we can use it anywhere for conditional stuff
ARG TARGETPLATFORM
ARG TARGETARCH
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}
ENV OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux" \
    APP_VERSION="5.0.0" \
    ABSI_APP_NAME="moodle-absi" \
    ABSI_WELCOME="Welcome to ABS Technology Joint Stock Company" \
    LANG="C.UTF-8"

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libwebp-dev \
    libxml2-dev \
    libicu-dev \
    libpq-dev \
    libldap2-dev \
    libsasl2-dev \
    libxslt1-dev \
    libgd-dev \
    libmemcached-dev \
    zlib1g-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    curl \
    git \
    unzip \
    libonig-dev \
    gosu \
    cron \
    default-mysql-client \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/lib/x86_64-linux-gnu/ /usr/lib/aarch64-linux-gnu/ \
    && if [ ! -e /usr/lib/x86_64-linux-gnu/libldap.so ] && [ -e /usr/lib/libldap.so ]; then \
           ln -sf /usr/lib/libldap.so /usr/lib/x86_64-linux-gnu/libldap.so; \
       fi \
    && if [ ! -e /usr/lib/aarch64-linux-gnu/libldap.so ] && [ -e /usr/lib/libldap.so ]; then \
           ln -sf /usr/lib/libldap.so /usr/lib/aarch64-linux-gnu/libldap.so; \
       fi

# Configure PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
    mysqli \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    zip \
    gd \
    intl \
    soap \
    xsl \
    opcache \
    exif \
    calendar

# Attempt to install LDAP extension (may fail on some architectures)
RUN docker-php-ext-configure ldap --with-libdir=lib || true \
    && docker-php-ext-install ldap || echo "LDAP extension installation failed, but continuing build"

# Install additional PHP extensions
RUN pecl install memcached redis \
    && docker-php-ext-enable memcached redis

# Configure PHP for Moodle
RUN { \
    echo 'memory_limit = 512M'; \
    echo 'max_execution_time = 300'; \
    echo 'upload_max_filesize = 500M'; \
    echo 'post_max_size = 500M'; \
    echo 'max_input_vars = 5000'; \
    echo 'date.timezone = Asia/Ho_Chi_Minh'; \
    } > /usr/local/etc/php/conf.d/moodle.ini

# Configure Apache
RUN a2enmod rewrite expires headers ssl

# Configure Apache for non-root user
RUN sed -i 's/^export APACHE_RUN_USER=www-data/export APACHE_RUN_USER=moodleuser/' /etc/apache2/envvars \
    && sed -i 's/^export APACHE_RUN_GROUP=www-data/export APACHE_RUN_GROUP=moodleuser/' /etc/apache2/envvars

# Create moodleuser
RUN useradd -ms /bin/bash moodleuser

# Create directory structure
RUN mkdir -p /var/www/html /var/www/moodledata /var/www/logs/apache2

# Setup Apache logs
RUN mkdir -p /var/www/logs/apache2 \
    && touch /var/www/logs/apache2/access.log /var/www/logs/apache2/error.log \
    && chmod -R 777 /var/www/logs

# Setup Apache runtime directories for non-root
RUN mkdir -p /var/run/apache2 \
    && chmod -R 777 /var/run/apache2 \
    && mkdir -p /var/lock/apache2 \
    && chmod -R 777 /var/lock/apache2

# Create Apache SSL directory with proper permissions
RUN mkdir -p /etc/apache2/ssl \
    && chmod -R 755 /etc/apache2/ssl

# Setup entrypoint scripts
RUN mkdir -p /opt/absi/entrypoint/lib /opt/absi/scripts

# Download and install Moodle
RUN set -ex; \
    curl -o /tmp/moodle.tgz -SL https://download.moodle.org/download.php/direct/stable500/moodle-5.0.tgz; \
    mkdir -p /var/www/html; \
    tar -xzf /tmp/moodle.tgz -C /var/www/html --strip-components=1; \
    rm /tmp/moodle.tgz

# Copy entrypoint scripts - Cấu trúc module hóa mới
COPY entrypoint/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY entrypoint/lib/* /opt/absi/entrypoint/lib/

# Copy utility scripts
COPY scripts/* /opt/absi/scripts/
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh

# Copy Apache configs
COPY config/apache-moodle.conf /etc/apache2/sites-available/000-default.conf

# Copy htaccess template
COPY config/htaccess.template /var/www/html/config/htaccess.template

# Copy config.php template if exists
COPY config/config.php.template /var/www/html/config.php.template

# Copy license notice
COPY assets/LICENSE-NOTICE.txt /opt/absi/LICENSE-NOTICE.txt

# Make scripts executable
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/healthcheck.sh \
    && if [ -d "/opt/absi/entrypoint/lib" ]; then chmod +x /opt/absi/entrypoint/lib/*.sh; fi \
    && if [ -d "/opt/absi/scripts" ]; then chmod +x /opt/absi/scripts/*.sh; fi

# Set proper permissions
RUN chown -R moodleuser:moodleuser /var/www

# Set environment variables - support both HTTP and HTTPS
ENV APACHE_LOG_DIR=/var/www/logs/apache2 \
    MOODLE_DATAROOT=/var/www/moodledata \
    MOODLE_ENABLE_SSL=true \
    MOODLE_WWWROOT=https://localhost \
    MOODLE_DATABASE_TYPE=mariadb \
    MOODLE_DATABASE_HOST=db \
    MOODLE_DATABASE_PORT=3306 \
    MOODLE_DATABASE_NAME=moodle \
    MOODLE_DATABASE_USER=moodle \
    MOODLE_DATABASE_PREFIX=mdl_ \
    MOODLE_ADMIN_USER=admin \
    MOODLE_ADMIN_EMAIL=admin@example.com \
    MOODLE_SITE_NAME="Moodle LMS" \
    MOODLE_SITE_FULLNAME="Moodle Learning Management System" \
    MOODLE_SITE_SHORTNAME="Moodle LMS" \
    MOODLE_REVERSEPROXY=false \
    MOODLE_SSLPROXY=true \
    MOODLE_LANG=vi \
    PHP_MAX_EXECUTION_TIME=300 \
    PHP_MEMORY_LIMIT=512M \
    PHP_UPLOAD_MAX_FILESIZE=50M \
    PHP_POST_MAX_SIZE=50M

# Set timezone for Vietnam
RUN ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime && \
    echo "Asia/Ho_Chi_Minh" > /etc/timezone

# Clean up to reduce image size
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/* && \
    find /var/log -type f -delete && \
    find /usr/share/doc -depth -type f ! -name copyright -delete && \
    find /usr/share/doc -empty -delete && \
    rm -rf /usr/share/man/* /usr/share/groff/* /usr/share/info/* && \
    rm -rf /usr/share/lintian/* /usr/share/linda/* /var/cache/man/*

# Expose ports
EXPOSE 80 443

# Set working directory
WORKDIR /var/www/html

# Setup healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 CMD ["/usr/local/bin/healthcheck.sh"]

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]

# Set label with license information
LABEL org.opencontainers.image.title="Moodle ABSI" \
      org.opencontainers.image.description="Moodle LMS packaged by ABS Technology Joint Stock Company" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.vendor="ABS Technology Joint Stock Company" \
      org.opencontainers.image.licenses="Apache-2.0 AND GPL-3.0" \
      org.opencontainers.image.url="https://abs.education/" \
      org.opencontainers.image.documentation="https://abs.education/docs/" \
      com.absi.license-notice="/opt/absi/LICENSE-NOTICE.txt" \
      com.absi.moodle.license="GPL-3.0" \
      com.absi.docker-structure.license="Apache-2.0" \
      com.absi.customizations.license="Apache-2.0" \
      com.absi.original-source="https://github.com/moodle/moodle-docker" 