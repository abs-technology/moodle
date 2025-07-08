# Multi-stage build for optimization
FROM debian:12-slim AS base

ARG MOODLE_VERSION=5.0.1
ARG PHP_VERSION=8.2
ARG APACHE_VERSION=2.4

# Set environment variables
ENV APACHE_RUN_DIR=/var/run/apache2

# Gói cài đặt: Apache, PHP-FPM, PHP CLI, MariaDB/MySQL client, các module PHP cần thiết
# Đảm bảo cài đặt đủ các dependency
RUN apt-get update && apt-get install -y --no-install-recommends \
    apache2 \
    apache2-utils \
    php${PHP_VERSION} \
    libapache2-mod-php${PHP_VERSION} \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-mysqlnd \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-mysqli \
    php${PHP_VERSION}-pdo \
    php${PHP_VERSION}-pdo-mysql \
    cron \
    locales \
    mariadb-client \
    curl \
    acl \
    ca-certificates \
    ssl-cert \
    openssl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Configure locale for UTF-8 support
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Enable PHP extensions
RUN phpenmod mysqli pdo pdo_mysql opcache

# Cấu hình user và group với UID/GID phổ biến cho bind volumes
RUN groupadd -g 1000 absiuser && \
    useradd -u 1000 -g absiuser -m -s /bin/bash absiuser

# Tạo các thư mục cần thiết
RUN mkdir -p /var/www/html \
           /var/www/moodledata \
           /var/log/apache2 \
           /var/run/apache2 \
           /var/run/php \
           /var/lock/apache2 \
           /scripts/ \
           /scripts/lib/ \
           /scripts/setup/ \
           /docker-entrypoint-init.d/

# Set quyền cho các thư mục Apache
RUN chown -R absiuser:absiuser /var/log/apache2 \
    && chown -R absiuser:absiuser /var/run/apache2 \
    && chown -R absiuser:absiuser /var/lock/apache2 \
    && chmod -R 755 /var/log/apache2 \
    && chmod -R 755 /var/run/apache2 \
    && chmod -R 755 /var/lock/apache2 \
    && touch /var/log/apache2/access.log \
    && touch /var/log/apache2/error.log \
    && touch /var/log/apache2/other_vhosts_access.log \
    && chown absiuser:absiuser /var/log/apache2/access.log \
    && chown absiuser:absiuser /var/log/apache2/error.log \
    && chown absiuser:absiuser /var/log/apache2/other_vhosts_access.log \
    && chmod 644 /var/log/apache2/access.log \
    && chmod 644 /var/log/apache2/error.log \
    && chmod 644 /var/log/apache2/other_vhosts_access.log

# Copy các script đã tinh gọn
COPY scripts/entrypoint.sh /scripts/entrypoint.sh
COPY scripts/moodle-run.sh /scripts/moodle-run.sh
COPY scripts/setup/ /scripts/setup/
COPY scripts/lib/ /scripts/lib/
COPY scripts/post-init.d/ /docker-entrypoint-init.d/

# ================================
# Moodle download stage (separate)
# ================================
FROM base AS moodle-downloader

# Download và extract Moodle
RUN curl -fsSL https://packaging.moodle.org/stable500/moodle-latest-500.tgz -o /tmp/moodle.tgz \
    && mkdir -p /opt/moodle-source \
    && tar -xzf /tmp/moodle.tgz -C /opt/moodle-source --strip-components=1 \
    && rm -f /tmp/moodle.tgz \
    && find /opt/moodle-source -type d -exec chmod 755 {} + \
    && find /opt/moodle-source -type f -exec chmod 644 {} +

# ================================
# Final stage
# ================================
FROM base AS final

# Copy Moodle source from downloader stage
COPY --from=moodle-downloader --chown=absiuser:absiuser /opt/moodle-source /opt/moodle-source

# Ghi đè cấu hình Apache mặc định cho Docker
COPY config/apache/apache2.conf /etc/apache2/apache2.conf
COPY config/apache/sites/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY config/apache/sites/000-default-ssl.conf /etc/apache2/sites-available/000-default-ssl.conf
COPY config/apache/conf/other-vhosts-access-log.conf /etc/apache2/conf-available/other-vhosts-access-log.conf
RUN a2ensite 000-default.conf \
    && a2ensite 000-default-ssl.conf \
    && a2enconf other-vhosts-access-log \
    && a2enmod proxy_fcgi setenvif rewrite \
    && a2enmod mpm_prefork \
    && a2enmod ssl \
    && a2enmod headers \
    && a2enmod remoteip

# Cấu hình PHP
COPY config/php/php.ini /etc/php/${PHP_VERSION}/fpm/php.ini
COPY config/php/pool.d/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
RUN rm -f /etc/php/${PHP_VERSION}/cli/php.ini \
    && ln -s /etc/php/${PHP_VERSION}/fpm/php.ini /etc/php/${PHP_VERSION}/cli/php.ini

# Cấu hình log của Apache và PHP-FPM ra stdout/stderr
RUN ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log \
    && ln -sf /dev/stdout /var/log/apache2/other_vhosts_access.log \
    && ln -sf /dev/stdout /var/log/php${PHP_VERSION}-fpm.log

# Đảm bảo quyền cho các thư mục dữ liệu và log
RUN chown -R absiuser:absiuser /var/www/moodledata \
    && chmod -R 775 /var/www/moodledata \
    && chown -R absiuser:absiuser /var/run/php \
    && chmod -R 775 /var/run/php \
    && chown -R absiuser:absiuser /scripts \
    && find /scripts -type f -exec chmod +x {} + \
    && find /docker-entrypoint-init.d/ -type f -exec chmod +x {} +

WORKDIR /var/www/html

# Expose cổng mặc định
EXPOSE 80 443

# Entrypoint cho container
ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["/scripts/moodle-run.sh"]
