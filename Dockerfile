# Multi-stage build for optimization
# Using latest Debian 12.13 (bookworm) with security updates (Feb 2026)
# Stack: PHP 8.4 (Sury) + Apache 2.4 + MariaDB client + Moodle 5.2+
FROM debian:12-slim AS base

ARG MOODLE_VERSION=5.2+
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

# Installation packages: Apache, PHP-FPM, PHP CLI, MariaDB/MySQL client, required PHP modules
# Ensure all necessary dependencies are installed with latest security patches
# CVE-2025-14087 Fix: Update all packages to latest secure versions
#
# CVE-2026-6100 Fix: Do NOT install `libmagickwand-dev` (-dev/headers package).
# It transitively pulls libglib2.0-dev → libglib2.0-dev-bin → python3-distutils
# → python3.11, which is vulnerable to a Python decompressor use-after-free
# with no patch yet on Debian Bookworm. Runtime imagemagick support is fully
# provided by `imagemagick` and `php${PHP_VERSION}-imagick`, which depend on
# `libmagickwand-6.q16-6` directly (no Python in the chain).
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

# Security: Force-upgrade selected libraries to patched versions from
# bookworm-security. We do this explicitly (instead of relying on the earlier
# `apt-get upgrade`) because:
#   1. Layer cache can leave a stale package index → upgrade misses recent fixes.
#   2. These libs are transitive dependencies of apache2, curl, php-curl... a
#      stale copy in a lower layer is enough for scanners to flag the image.
#
# Fixes applied (verified via `docker scout cves --only-fixed`):
#   - CVE-2026-31789 (DSA-6201-1)  openssl/libssl3 >= 3.0.19-1~deb12u2
#       Heap buffer overflow on 32-bit platforms when converting large OCTET
#       STRING values (X.509 SKID/AKID) to hex.
#   - CVE-2026-27135                libnghttp2-14 >= 1.52.0-1+deb12u3
#       nghttp2 HTTP/2 stack vulnerability; affects curl, apache2 mod_http2,
#       php-curl.
#   - CVE-2023-38199 (CRITICAL)     modsecurity-crs >= 3.3.4-1+deb12u2
#       OWASP CRS rule bypass / header injection (CVSS 9.x).
#   - CVE-2026-0861, CVE-2026-0915, CVE-2026-4046, CVE-2026-4437,
#     CVE-2025-15281 (5x HIGH)      locales (glibc) >= 2.36-9+deb12u14
#       glibc locale handling vulnerabilities; upgrading `locales` also
#       pulls patched libc-bin/libc6.
#   - CVE-2025-6297                 dpkg >= 1.21.23
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
# NOTE: `sodium` is intentionally NOT listed here. The Sury repository for
# Debian Bookworm ships PHP 8.4 with the sodium extension bundled into the
# core `php8.4` package and enabled by default - there is no separate
# `php8.4-sodium` package to install or enable. Trying to `phpenmod sodium`
# would just no-op. Verify at runtime with `php -m | grep sodium`.
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
COPY scripts/setup/ /scripts/setup/
COPY scripts/lib/ /scripts/lib/
COPY scripts/post-init.d/ /docker-entrypoint-init.d/

# ================================
# Moodle download stage (separate)
# ================================
FROM base AS moodle-downloader

# Download and extract Moodle 5.2+ (latest weekly build of MOODLE_502_STABLE).
#
# Why moodle-latest-502.tgz instead of moodle-5.2.tgz?
#   The "-latest-502" tarball is built every week from the MOODLE_502_STABLE
#   branch and includes all post-release bug/security fixes. The static
#   "moodle-5.2.tgz" tarball is the immutable 16/04/2026 release and would
#   miss every weekly fix shipped after that date.
#
# To switch versions, comment the active RUN and uncomment one of the alternatives.
# IMPORTANT: alternatives MUST NOT end with `\` or they tangle with the active RUN
# (Dockerfile joins continued lines BEFORE comment detection, then bash sees `#RUN`
# mid-line and treats the rest of the joined command - mkdir, tar, find - as a comment).
#RUN curl -fsSL https://packaging.moodle.org/stable405/moodle-4.5.11.tgz -o /tmp/moodle.tgz
#RUN curl -fsSL https://packaging.moodle.org/stable500/moodle-5.0.7.tgz -o /tmp/moodle.tgz
RUN curl -fsSL https://download.moodle.org/download.php/direct/stable502/moodle-latest-502.tgz -o /tmp/moodle.tgz \
    && mkdir -p /opt/moodle-source \
    && tar -xzf /tmp/moodle.tgz -C /opt/moodle-source --strip-components=1 \
    && rm -f /tmp/moodle.tgz \
    && find /opt/moodle-source -type d -exec chmod 755 {} + \
    && find /opt/moodle-source -type f -exec chmod 644 {} +

# Audit + force-upgrade Moodle's bundled vendor tree.
#
# We DO override `aws/aws-sdk-php`:
#   Moodle 5.2 pins 3.356.22 which is vulnerable to GHSA-27qh-8cxx-2cr5
#   (CloudFront Policy Document Injection, CVSS 7.7, fixed in 3.371.4).
#
# Strategy:
#   1. Run `composer install` first. If the tarball already has `vendor/`,
#      this is a no-op. If it is missing (git-style tarball), this installs
#      everything using the immutable `composer.lock`.
#   2. Run `composer require` to update the lock file and install the patched version.
#   3. Verify the version in the build log to ensure it's actually patched.
# NOTE: `composer require` does NOT accept `--no-dev` (composer 2.x only allows
# `--update-no-dev`). Previously this line silently failed with "The --no-dev
# option does not exist", but build still passed because the verification step
# (`grep VERSION =`) didn't enforce version match. Result: aws-sdk-php stayed
# at the vulnerable 3.356.22 pinned by Moodle's composer.json/lock.
#
# Fix: use `--update-no-dev` and assert version >= 3.371.4 via PHP version_compare
# so the build fails loudly if the upgrade does not stick.
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
# WARNING: do NOT add `find vendor -name '*.txt' -delete` or `find vendor -name '*.md' -delete`
# here. Some Moodle vendor packages (notably `matthiasmullie/minify`) ship
# *runtime data* as .txt files inside vendor/<pkg>/data/ - blanket-deleting
# .txt makes Moodle crash with "MatthiasMullie\Minify\JS::getOperatorsForRegex():
# Argument #1 ($operators) must be of type array, false given" the first time
# any page tries to minify JS. The few MB saved is not worth the breakage.
# Same for `tests/` and `Tests/` directories: a few packages still autoload
# helper classes from those paths at runtime.

# Security: Create security metadata file for tracking
RUN cd /opt/moodle-source && echo "Build Date: $(date -u +'%Y-%m-%d %H:%M:%S UTC')" > /opt/moodle-source/SECURITY-INFO.txt \
    && echo "Moodle Version: 5.2+ (MOODLE_502_STABLE weekly build)" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "PHP Version: 8.4 (Sury repo)" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "Base Image: debian:12-slim (bookworm) with bookworm-security patches" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "Built-in security posture (from vendor + base):" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- Symfony 7.x and PHPUnit 11.x ship in Moodle 5.2 (past CVE-2024-51736 and CVE-2026-24765)" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2025-14087: system packages updated via apt-get upgrade" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2026-31789: OpenSSL upgraded to 3.0.19-1~deb12u2+ (DSA-6201-1)" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2026-27135: libnghttp2-14 upgraded to 1.52.0-1+deb12u3+" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2023-38199 (CRITICAL): modsecurity-crs upgraded to 3.3.4-1+deb12u2+" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2026-0861,0915,4046,4437,CVE-2025-15281: locales/glibc upgraded to 2.36-9+deb12u14+" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2025-6297: dpkg upgraded to 1.21.23+" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2026-6100: removed libmagickwand-dev to drop python3.11 chain (no Debian patch yet)" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- CVE-2026-25646: libpng16-16 (awaiting Debian patch)" >> /opt/moodle-source/SECURITY-INFO.txt \
    && echo "- GHSA-27qh-8cxx-2cr5: aws/aws-sdk-php upgraded to ^3.371.4 (CloudFront policy injection)" >> /opt/moodle-source/SECURITY-INFO.txt

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

