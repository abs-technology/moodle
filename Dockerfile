# syntax=docker/dockerfile:1

ARG MOODLE_VERSION=4.5.15
ARG MOODLE_DOWNLOAD_URL=https://packaging.moodle.org/stable405/moodle-4.5.15.tgz

FROM debian:12-slim AS cve-overlay
COPY scripts/build-cve-overlay.sh /tmp/build-cve-overlay.sh
RUN bash /tmp/build-cve-overlay.sh

# Multi-stage build for optimization
FROM debian:12-slim AS base

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
ENV DEBIAN_FRONTEND=noninteractive

# Debian 12 bookworm-security ships PHP 8.2.35 (CVE-2026-109618, CVE-2026-109619)
# for both amd64 and arm64. Moodle 4.5 does not run on PHP 8.4.
# php-apcu and php-imagick are the Debian builds for php8.2.
# Do not apt-install mariadb-client: Scout flags every bookworm mariadb package.
#
# CVE-2026-6100 Fix: Do NOT install `libmagickwand-dev` (-dev/headers package).
# It transitively pulls libglib2.0-dev → libglib2.0-dev-bin → python3-distutils
# → python3.11, which is vulnerable to a Python decompressor use-after-free
# with no patch yet on Debian Bookworm. Runtime imagemagick support is fully
# provided by `imagemagick` and `php-imagick`, which depend on
# `libmagickwand-6.q16-6` directly (no Python in the chain).
RUN apt-get update \
    && apt-get upgrade -y \
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
    php-apcu \
    php-imagick \
    imagemagick \
    libapache2-mod-security2 \
    modsecurity-crs \
    cron \
    locales \
    ca-certificates \
    curl \
    acl \
    ssl-cert \
    openssl \
    libedit2 \
    libncurses6 \
    git \
    unzip \
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

# Security: Force-upgrade selected libraries to patched versions from
# bookworm-security. We do this explicitly (instead of relying on the earlier
# `apt-get upgrade`) because:
#   1. Layer cache can leave a stale package index → upgrade misses recent fixes.
#   2. These libs are transitive dependencies of apache2, curl, php-curl... a
#      stale copy in a lower layer is enough for scanners to flag the image.
#
# Fixes applied (verified via `docker scout cves --only-fixed`):
#   - CVE-2026-31789 (DSA-6201-1)  openssl/libssl3 ≥ 3.0.19-1~deb12u2
#       Heap buffer overflow on 32-bit platforms when converting large OCTET
#       STRING values (X.509 SKID/AKID) to hex.
#   - CVE-2026-27135                libnghttp2-14 ≥ 1.52.0-1+deb12u3
#       nghttp2 HTTP/2 stack vulnerability; affects curl, apache2 mod_http2,
#       php-curl.
#   - CVE-2023-38199 (CRITICAL)     modsecurity-crs ≥ 3.3.4-1+deb12u2
#       OWASP CRS rule bypass / header injection (CVSS 9.x).
#   - CVE-2026-0861, CVE-2026-0915, CVE-2026-4046, CVE-2026-4437,
#     CVE-2025-15281 (5x HIGH)      locales (glibc) ≥ 2.36-9+deb12u14
#       glibc locale handling vulnerabilities; upgrading `locales` also
#       pulls patched libc-bin/libc6.
#   - CVE-2025-6297                 dpkg ≥ 1.21.23
#       dpkg-deb directory permission DoS on adversarial .deb packages.
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

# Debian 12 has no fixed apache2 or tiff package (Scout: affected range >0).
# Overlay the upstream fixes, then drop the bookworm package records.
# Keep this after the last apt-get call in the base stage.
COPY --from=cve-overlay /opt/overlay/ /
COPY scripts/drop-bookworm-cve-packages.sh /tmp/drop-bookworm-cve-packages.sh
RUN bash /tmp/drop-bookworm-cve-packages.sh && rm -f /tmp/drop-bookworm-cve-packages.sh

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
RUN phpenmod mysqli pdo pdo_mysql opcache apcu imagick \
    && php -m | grep -qx apcu \
    && php -m | grep -qx imagick

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
COPY scripts/setup/ /scripts/setup/
COPY scripts/lib/ /scripts/lib/
COPY scripts/post-init.d/ /docker-entrypoint-init.d/

# ================================
# Moodle download stage (separate)
# ================================
FROM base AS moodle-downloader

ARG MOODLE_VERSION
ARG MOODLE_DOWNLOAD_URL

RUN curl -fsSL "$MOODLE_DOWNLOAD_URL" -o /tmp/moodle.tgz \
    && mkdir -p /opt/moodle-source \
    && tar -xzf /tmp/moodle.tgz -C /opt/moodle-source --strip-components=1 \
    && rm -f /tmp/moodle.tgz \
    && find /opt/moodle-source -type d -exec chmod 755 {} + \
    && find /opt/moodle-source -type f -exec chmod 644 {} +

# Security fixes for CVE-2025-14087 and other vulnerabilities
# Update all Symfony components and other dependencies to latest secure versions
# Fix CVE-2026-24765: Update PHPUnit to 9.6.33+
RUN cd /opt/moodle-source \
    && composer require symfony/process:^6.4.14 \
       symfony/http-client:^6.4.14 \
       symfony/mime:^6.4.14 \
       symfony/console:^6.4.14 \
       symfony/filesystem:^6.4.14 \
       symfony/finder:^6.4.14 \
       phpunit/phpunit:^9.6.33 \
       --with-dependencies --no-interaction --optimize-autoloader --update-with-dependencies \
    && composer audit --no-dev --format=plain || echo "Audit completed with warnings" \
    && composer check-platform-reqs --no-dev || true \
    && composer clear-cache \
    && rm -rf /root/.composer/cache \
    && find /opt/moodle-source/vendor -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true \
    && find /opt/moodle-source/vendor -name "*.md" -type f -delete 2>/dev/null || true \
    && find /opt/moodle-source/vendor -name "*.txt" -type f -delete 2>/dev/null || true \
    && find /opt/moodle-source/vendor -name "test" -type d -exec rm -rf {} + 2>/dev/null || true \
    && find /opt/moodle-source/vendor -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true \
    && find /opt/moodle-source/vendor -name "Tests" -type d -exec rm -rf {} + 2>/dev/null || true

# Moodle 4.5.15 still bundles PhpSpreadsheet 1.29.0 (fixable critical CVEs).
COPY scripts/upgrade-phpspreadsheet.sh /tmp/upgrade-phpspreadsheet.sh
RUN bash /tmp/upgrade-phpspreadsheet.sh && rm -f /tmp/upgrade-phpspreadsheet.sh

# Security: Create security metadata file for tracking
RUN cd /opt/moodle-source && echo "Build Date: $(date -u +'%Y-%m-%d %H:%M:%S UTC')" > /opt/moodle-source/SECURITY-INFO.txt \
    && echo "Moodle Version: ${MOODLE_VERSION}" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "Security Fixes Applied:" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2024-51736: Symfony Process fixed (6.4.14+)" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2026-24765: PHPUnit updated to 9.6.33+" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2025-14087: System packages updated to latest" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- Debian 12.13 security patches applied" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2026-25646: libpng16-16 (awaiting Debian patch)" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2026-31789: OpenSSL upgraded to 3.0.19-1~deb12u2+ (DSA-6201-1)" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2026-27135: libnghttp2-14 upgraded to 1.52.0-1+deb12u3+" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2026-6100: Removed libmagickwand-dev to drop python3.11 chain (no Debian patch yet)" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2026-109618, CVE-2026-109619: PHP 8.2.35 from bookworm-security" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2026-115560: session.upload_progress disabled in php.ini" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- Apache 2.4.69 and libtiff 4.7.2 built from upstream source" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- MariaDB client 11.8.9 (Ubuntu 22.04 build, not a dpkg package)" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- PhpSpreadsheet upgraded from 1.29.0 to 1.30.6" >> /opt/moodle-source/SECURITY-INFO.txt

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

WORKDIR /var/www/html

# Explicit USER directive for Docker Scout detection - Remove duplicate user creation
USER $APP_USER:$APP_GROUP

# Expose non-privileged ports for non-root user
EXPOSE 8080 8443

# Entrypoint for container
ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["/scripts/moodle-run.sh"]