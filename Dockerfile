FROM debian:12-slim AS base

ARG MOODLE_VERSION=5.2.1+
ARG MOODLE_RELEASE_PREFIX=5.2.1
ARG MOODLE_DOWNLOAD_URL=https://download.moodle.org/download.php/direct/stable502/moodle-latest-502.tgz
ARG PHP_VERSION=8.4
ARG APACHE_VERSION=2.4
ARG APP_USER=absiuser
ARG APP_GROUP=absiuser
ARG APP_UID=1000
ARG APP_GID=1000

# Set environment variables
ENV APACHE_RUN_DIR=/var/run/apache2
ENV PHP_VERSION=$PHP_VERSION
ENV APP_USER=$APP_USER
ENV APP_GROUP=$APP_GROUP
ENV DEBIAN_FRONTEND=noninteractive

# Security: Add Debian security repository and update to latest patches
# Fix for CVE-2025-14087 and other security vulnerabilities
RUN echo "deb http://security.debian.org/ bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    lsb-release \
    wget \
    gnupg2 \
    && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
    && apt-get update

RUN apt-get install -y --no-install-recommends \
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
    php${PHP_VERSION}-apcu \
    php${PHP_VERSION}-imagick \
    imagemagick \
    libapache2-mod-security2 \
    modsecurity-crs \
    cron \
    locales \
    mariadb-client \
    curl \
    acl \
    ssl-cert \
    openssl \
    git \
    unzip \
    libcap2-bin \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN apt-get update \
    && apt-get install -y --no-install-recommends --only-upgrade \
        openssl \
        libssl3 \
        libnghttp2-14 \
        modsecurity-crs \
        locales \
        dpkg \
    && dpkg-query -W -f='${Package} ${Version}\n' \
        openssl libssl3 libnghttp2-14 modsecurity-crs locales dpkg \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Security: Remove unnecessary packages and clean up
RUN apt-get autoremove -y \
    && apt-get autoclean -y

# Install Composer for dependency management and security updates
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && chmod +x /usr/local/bin/composer \
    && rm -rf /tmp/composer-setup.php

# Configure locale for UTF-8 support
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Enable PHP extensions

RUN phpenmod mysqli pdo pdo_mysql opcache apcu imagick

# Configure user and group with common UID/GID for bind volumes - Consolidated user creation
RUN groupadd -g $APP_GID $APP_GROUP 2>/dev/null || true \
    && id -u $APP_USER >/dev/null 2>&1 || useradd -u $APP_UID -g $APP_GID -m -s /bin/bash $APP_USER \
    && usermod -a -G crontab $APP_USER 2>/dev/null || true

# Create necessary directories
RUN mkdir -p /var/www/html \
           /var/www/moodledata \
           /var/www/moodle-backups \
           /var/log/apache2 \
           /var/run/apache2 \
           /var/run/php \
           /var/lock/apache2 \
           /scripts/ \
           /scripts/lib/ \
           /scripts/setup/ \
           /docker-entrypoint-init.d/

# Set permissions for Apache directories
RUN chown -R $APP_USER:$APP_GROUP /var/log/apache2 \
    && chown -R $APP_USER:$APP_GROUP /var/run/apache2 \
    && chown -R $APP_USER:$APP_GROUP /var/lock/apache2 \
    && chmod -R 755 /var/log/apache2 \
    && chmod -R 755 /var/run/apache2 \
    && chmod -R 755 /var/lock/apache2 \
    && touch /var/log/apache2/access.log \
    && touch /var/log/apache2/error.log \
    && touch /var/log/apache2/other_vhosts_access.log \
    && chown $APP_USER:$APP_GROUP /var/log/apache2/access.log \
    && chown $APP_USER:$APP_GROUP /var/log/apache2/error.log \
    && chown $APP_USER:$APP_GROUP /var/log/apache2/other_vhosts_access.log \
    && chmod 644 /var/log/apache2/access.log \
    && chmod 644 /var/log/apache2/error.log \
    && chmod 644 /var/log/apache2/other_vhosts_access.log

# Copy streamlined scripts
COPY scripts/entrypoint.sh /scripts/entrypoint.sh
COPY scripts/moodle-run.sh /scripts/moodle-run.sh
COPY scripts/verify-moodle-layout.sh /scripts/verify-moodle-layout.sh
COPY scripts/setup/ /scripts/setup/
COPY scripts/lib/ /scripts/lib/
COPY scripts/post-init.d/ /docker-entrypoint-init.d/
RUN chmod +x /scripts/verify-moodle-layout.sh

# ================================
# Moodle download stage (separate)
# ================================
FROM base AS moodle-downloader

ARG MOODLE_VERSION
ARG MOODLE_RELEASE_PREFIX
ARG MOODLE_DOWNLOAD_URL

RUN curl -fsSL "${MOODLE_DOWNLOAD_URL}" -o /tmp/moodle.tgz \
    && mkdir -p /opt/moodle-source \
    && tar -xzf /tmp/moodle.tgz -C /opt/moodle-source --strip-components=1 \
    && rm -f /tmp/moodle.tgz \
    && find /opt/moodle-source -type d -exec chmod 755 {} + \
    && find /opt/moodle-source -type f -exec chmod 644 {} + \
    && MOODLE_VERSION="${MOODLE_VERSION}" MOODLE_RELEASE_PREFIX="${MOODLE_RELEASE_PREFIX}" \
       bash /scripts/verify-moodle-layout.sh /opt/moodle-source

#
RUN cd /opt/moodle-source \
    && composer install --no-dev --no-interaction --no-progress --optimize-autoloader \
    && composer require "aws/aws-sdk-php:^3.371.4" \
           --update-no-dev --no-interaction --no-progress \
           --update-with-all-dependencies \
           --optimize-autoloader \
           --classmap-authoritative \
    && AWS_SDK_VER=$(php -r "require 'vendor/autoload.php'; echo Aws\Sdk::VERSION;") \
    && echo "aws-sdk-php version in image: $AWS_SDK_VER" \
    && php -r "exit(version_compare('$AWS_SDK_VER', '3.371.4', '<') ? 1 : 0);" \
    && composer audit --no-dev --format=plain || echo "Audit completed with warnings" \
    && composer check-platform-reqs --no-dev || true \
    && composer clear-cache \
    && rm -rf /root/.composer/cache \
    && find /opt/moodle-source/vendor -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true \
    && cd /opt/moodle-source && composer dump-autoload --no-dev --classmap-authoritative

# ================================
# Final stage
# ================================
FROM base AS final

ARG MOODLE_VERSION
ARG MOODLE_RELEASE_PREFIX
ARG PHP_VERSION

LABEL org.opencontainers.image.version="${MOODLE_VERSION}" \
      ai.absi.moodle.version="${MOODLE_VERSION}" \
      ai.absi.moodle.release-prefix="${MOODLE_RELEASE_PREFIX}" \
      ai.absi.moodle.layout="5" \
      ai.absi.moodle.php="${PHP_VERSION}"

ENV MOODLE_VERSION=${MOODLE_VERSION} \
    MOODLE_RELEASE_PREFIX=${MOODLE_RELEASE_PREFIX} \
    MOODLE_LAYOUT=5

# Copy Moodle source from downloader stage
COPY --from=moodle-downloader --chown=$APP_USER:$APP_GROUP /opt/moodle-source /opt/moodle-source

# Override default Apache configuration for Docker
COPY config/apache/apache2.conf /etc/apache2/apache2.conf
COPY config/apache/sites/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY config/apache/sites/000-default-ssl.conf /etc/apache2/sites-available/000-default-ssl.conf
COPY config/apache/conf/other-vhosts-access-log.conf /etc/apache2/conf-available/other-vhosts-access-log.conf
COPY config/apache/conf/security2.conf /etc/apache2/conf-available/security2.conf
RUN a2ensite 000-default.conf \
    && a2ensite 000-default-ssl.conf \
    && a2enconf other-vhosts-access-log \
    && a2enconf security2 \
    && a2enmod proxy_fcgi setenvif rewrite \
    && a2enmod mpm_prefork \
    && a2enmod ssl \
    && a2enmod headers \
    && a2enmod remoteip \
    && a2enmod security2 \
    && a2enmod unique_id

# Configure PHP for both FPM and Apache
COPY config/php/php.ini /etc/php/${PHP_VERSION}/fpm/php.ini
COPY config/php/php.ini /etc/php/${PHP_VERSION}/apache2/php.ini
COPY config/php/pool.d/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf

# Bake a self-signed TLS certificate for `localhost` and trust it system-wide.
RUN openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -subj "/C=VN/ST=HCM/L=HCM/O=ABSI/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,DNS:*.localhost,IP:127.0.0.1,IP:0.0.0.0" \
        -keyout /etc/ssl/private/localhost.key \
        -out /etc/ssl/certs/localhost.crt \
    && cp /etc/ssl/certs/localhost.crt /usr/local/share/ca-certificates/moodle-localhost.crt \
    && update-ca-certificates \
    && chmod 644 /etc/ssl/certs/localhost.crt \
    && chmod 640 /etc/ssl/private/localhost.key

# Set permissions for config directories and files so non-root user can modify at runtime
RUN chown -R $APP_USER:$APP_GROUP /etc/apache2 \
    && chown -R $APP_USER:$APP_GROUP /etc/php/${PHP_VERSION}/fpm \
    && chown -R $APP_USER:$APP_GROUP /etc/php/${PHP_VERSION}/apache2 \
    && chown -R $APP_USER:$APP_GROUP /etc/ssl/certs \
    && chown -R $APP_USER:$APP_GROUP /etc/ssl/private \
    && chown $APP_USER:$APP_GROUP /var/run
RUN rm -f /etc/php/${PHP_VERSION}/cli/php.ini \
    && ln -s /etc/php/${PHP_VERSION}/fpm/php.ini /etc/php/${PHP_VERSION}/cli/php.ini

# Configure Apache and PHP-FPM logs to stdout/stderr
RUN ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log \
    && ln -sf /dev/stdout /var/log/apache2/other_vhosts_access.log \
    && ln -sf /dev/stdout /var/log/php${PHP_VERSION}-fpm.log

# Ensure permissions for data and log directories
RUN chown -R $APP_USER:$APP_GROUP /var/www/moodledata \
    && chmod -R 775 /var/www/moodledata \
    && chown -R $APP_USER:$APP_GROUP /var/www/moodle-backups \
    && chmod -R 775 /var/www/moodle-backups \
    && chown -R $APP_USER:$APP_GROUP /var/run/php \
    && chmod -R 775 /var/run/php \
    && chown -R $APP_USER:$APP_GROUP /scripts \
    && find /scripts -type f -exec chmod +x {} + \
    && find /docker-entrypoint-init.d/ -type f -exec chmod +x {} +


RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/apache2 \
    && getcap /usr/sbin/apache2

WORKDIR /var/www/html

# Explicit USER directive for Docker Scout detection - Remove duplicate user creation
USER $APP_USER:$APP_GROUP

EXPOSE 8080 8443

# Entrypoint for container
ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["/scripts/moodle-run.sh"]

