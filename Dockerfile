# syntax=docker/dockerfile:1

FROM debian:12-slim AS cve-overlay
COPY scripts/build-cve-overlay.sh /tmp/build-cve-overlay.sh
RUN bash /tmp/build-cve-overlay.sh

# Multi-stage build for optimization
FROM debian:12-slim AS base

ARG MOODLE_VERSION=4.3.12
ARG MOODLE_RELEASE_PREFIX=4.3.12
ARG MOODLE_DOWNLOAD_URL=https://packaging.moodle.org/stable403/moodle-4.3.12.tgz
ARG PHP_VERSION=8.2
ARG PHP_RELEASE=8.2.35
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

# Debian 12 bookworm-security ships PHP 8.2.35 (CVE-2026-109618, CVE-2026-109619)
# for both amd64 and arm64. Moodle 4.3 does not run on PHP 8.3 or 8.4.
# Do not apt-install mariadb-client: Scout flags every bookworm mariadb package.
RUN apt-get update \
    && printf 'Package: php%s*\nPin: version %s*\nPin-Priority: 1001\n\nPackage: libapache2-mod-php%s\nPin: version %s*\nPin-Priority: 1001\n' \
        "$PHP_VERSION" "$PHP_RELEASE" "$PHP_VERSION" "$PHP_RELEASE" \
        > /etc/apt/preferences.d/php-release \
    && apt-get install -y --no-install-recommends \
    apache2 \
    apache2-utils \
    php${PHP_VERSION} \
    libapache2-mod-php${PHP_VERSION} \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-mysql \
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
    cron \
    locales \
    ca-certificates \
    curl \
    acl \
    ssl-cert \
    openssl \
    libedit2 \
    libncurses6 \
    && test "$(php -r 'echo PHP_VERSION;')" = "$PHP_RELEASE" \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Ubuntu 22.04 11.8.9 client debs run on Debian 12 and are not registered with
# dpkg, so Scout does not keep CVE-2026-92262 and CVE-2026-85746 on debian/mariadb.
RUN arch="$(dpkg --print-architecture)" \
    && base="https://dlm.mariadb.com/repo/mariadb-server/11.8/repo/ubuntu/pool/main/m/mariadb" \
    && curl -fsSL -o /tmp/mariadb-client-core.deb "${base}/mariadb-client-core_11.8.9+maria~ubu2204_${arch}.deb" \
    && curl -fsSL -o /tmp/mariadb-client.deb "${base}/mariadb-client_11.8.9+maria~ubu2204_${arch}.deb" \
    && mkdir -p /tmp/mdb \
    && dpkg-deb -x /tmp/mariadb-client-core.deb /tmp/mdb \
    && dpkg-deb -x /tmp/mariadb-client.deb /tmp/mdb \
    && install -m 755 /tmp/mdb/usr/bin/mariadb /usr/local/bin/mariadb \
    && install -m 755 /tmp/mdb/usr/bin/mariadb-dump /usr/local/bin/mariadb-dump \
    && ln -sf mariadb /usr/local/bin/mysql \
    && ln -sf mariadb-dump /usr/local/bin/mysqldump \
    && rm -rf /tmp/mdb /tmp/mariadb-client.deb /tmp/mariadb-client-core.deb \
    && mariadb --version | grep -q 'from 11.8.9-MariaDB' \
    && mariadb-dump --version | grep -q 'from 11.8.9-MariaDB' \
    && ! dpkg-query -W | grep -E '^(mariadb|libmariadb|mysql-common)'

# Debian 12 has no fixed apache2 or tiff package (Scout: affected range >0).
# Overlay the upstream fixes, then drop the bookworm package records.
COPY --from=cve-overlay /opt/overlay/ /
COPY scripts/drop-bookworm-cve-packages.sh /tmp/drop-bookworm-cve-packages.sh
RUN bash /tmp/drop-bookworm-cve-packages.sh && rm -f /tmp/drop-bookworm-cve-packages.sh

# Configure locale for UTF-8 support
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Enable PHP extensions
RUN phpenmod mysqli pdo pdo_mysql opcache

# Configure user and group with common UID/GID for bind volumes - Consolidated user creation
RUN groupadd -g $APP_GID $APP_GROUP 2>/dev/null || true \
    && id -u $APP_USER >/dev/null 2>&1 || useradd -u $APP_UID -g $APP_GID -m -s /bin/bash $APP_USER \
    && usermod -a -G crontab $APP_USER 2>/dev/null || true

# Create necessary directories
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
COPY scripts/setup/ /scripts/setup/
COPY scripts/lib/ /scripts/lib/
COPY scripts/post-init.d/ /docker-entrypoint-init.d/

# ================================
# Moodle download stage (separate)
# ================================
FROM base AS moodle-downloader

ARG MOODLE_DOWNLOAD_URL

# Download and extract Moodle

RUN curl -fsSL "$MOODLE_DOWNLOAD_URL" -o /tmp/moodle.tgz \
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
COPY --from=moodle-downloader --chown=$APP_USER:$APP_GROUP /opt/moodle-source /opt/moodle-source

# Override default Apache configuration for Docker
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

# Configure PHP for both FPM and Apache
COPY config/php/php.ini /etc/php/${PHP_VERSION}/fpm/php.ini
COPY config/php/php.ini /etc/php/${PHP_VERSION}/apache2/php.ini
COPY config/php/pool.d/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf

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
    && chown -R $APP_USER:$APP_GROUP /var/run/php \
    && chmod -R 775 /var/run/php \
    && chown -R $APP_USER:$APP_GROUP /scripts \
    && find /scripts -type f -exec chmod +x {} + \
    && find /docker-entrypoint-init.d/ -type f -exec chmod +x {} +

WORKDIR /var/www/html

# Explicit USER directive for Docker Scout detection - Remove duplicate user creation
USER $APP_USER:$APP_GROUP

# Expose non-privileged ports for non-root user
EXPOSE 8080 8443

# Entrypoint for container
ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["/scripts/moodle-run.sh"]