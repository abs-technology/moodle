# syntax=docker/dockerfile:1

FROM debian:12-slim AS cve-overlay
COPY scripts/build-cve-overlay.sh /tmp/build-cve-overlay.sh
RUN bash /tmp/build-cve-overlay.sh

FROM debian:12-slim AS base

ARG MOODLE_VERSION=5.2.3
ARG MOODLE_RELEASE_PREFIX=5.2.3
ARG MOODLE_DOWNLOAD_URL=https://packaging.moodle.org/stable502/moodle-5.2.3.tgz
ARG PHP_VERSION=8.4
ARG PHP_RELEASE=8.4.27
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
    && printf 'Package: php%s*\nPin: version %s*\nPin-Priority: 1001\n\nPackage: libapache2-mod-php%s\nPin: version %s*\nPin-Priority: 1001\n' \
        "$PHP_VERSION" "$PHP_RELEASE" "$PHP_VERSION" "$PHP_RELEASE" \
        > /etc/apt/preferences.d/php-release \
    && apt-get update

# amd64: Sury bookworm publishes PHP 8.4.27, so the pin above selects it.
# arm64: that index still ships php8.4-cli 8.4.26. The freexian12 packages in
# the same pool are 8.4.27 built against Debian 12 libraries (libicu72, libgd3).
RUN apt-get install -y --no-install-recommends \
    apache2 \
    apache2-utils \
    imagemagick \
    libapache2-mod-security2 \
    modsecurity-crs \
    cron \
    locales \
    libedit2 \
    libncurses6 \
    curl \
    acl \
    ssl-cert \
    openssl \
    git \
    unzip \
    libcap2-bin \
    && arch="$(dpkg --print-architecture)" \
    && if [ "$arch" = "amd64" ]; then \
        apt-get install -y --no-install-recommends \
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
            php${PHP_VERSION}-imagick; \
    else \
        apt-get install -y --no-install-recommends php-common ucf \
        && ver="${PHP_RELEASE}-1+freexian12.1+php+1" \
        && base="https://packages.sury.org/php/pool/main/p/php${PHP_VERSION}" \
        && mkdir -p /tmp/phpdebs \
        && for pkg in \
            php${PHP_VERSION}-common \
            php${PHP_VERSION}-opcache \
            php${PHP_VERSION}-readline \
            php${PHP_VERSION}-cli \
            libapache2-mod-php${PHP_VERSION} \
            php${PHP_VERSION}-fpm \
            php${PHP_VERSION}-mysql \
            php${PHP_VERSION}-curl \
            php${PHP_VERSION}-gd \
            php${PHP_VERSION}-intl \
            php${PHP_VERSION}-mbstring \
            php${PHP_VERSION}-xml \
            php${PHP_VERSION}-zip \
            php${PHP_VERSION}-soap; do \
            curl -fsSL -o "/tmp/phpdebs/${pkg}.deb" "${base}/${pkg}_${ver}_${arch}.deb"; \
        done \
        && dpkg -i /tmp/phpdebs/*.deb || apt-get install -y -f --no-install-recommends \
        && dpkg-query -W "php${PHP_VERSION}-cli" | grep -q "${PHP_RELEASE}" \
        && apt-mark hold \
            php${PHP_VERSION}-common \
            php${PHP_VERSION}-cli \
            php${PHP_VERSION}-opcache \
            php${PHP_VERSION}-readline \
            libapache2-mod-php${PHP_VERSION} \
            php${PHP_VERSION}-fpm \
            php${PHP_VERSION}-mysql \
            php${PHP_VERSION}-curl \
            php${PHP_VERSION}-gd \
            php${PHP_VERSION}-intl \
            php${PHP_VERSION}-mbstring \
            php${PHP_VERSION}-xml \
            php${PHP_VERSION}-zip \
            php${PHP_VERSION}-soap \
        && apt-get install -y --no-install-recommends \
            php${PHP_VERSION} \
            php${PHP_VERSION}-apcu \
            php${PHP_VERSION}-imagick \
        && rm -rf /tmp/phpdebs; \
    fi \
    && apt-get upgrade -y \
    && test "$(php -r 'echo PHP_VERSION;')" = "$PHP_RELEASE" \
    && php -m | grep -qx imagick \
    && php -m | grep -qx mysqli \
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
    && test "$(php -r 'echo PHP_VERSION;')" = "$PHP_RELEASE" \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Security: Remove unnecessary packages and clean up
RUN apt-get autoremove -y \
    && apt-get autoclean -y

# Debian 12 has no fixed apache2 or tiff package (Scout: affected range >0).
# Overlay the upstream fixes, then drop the bookworm package records.
COPY --from=cve-overlay /opt/overlay/ /
RUN ldconfig \
    && /usr/sbin/apache2 -v | grep -q 'Apache/2.4.69' \
    && grep -a -q 'LIBTIFF, Version 4.7.2' /usr/lib/*/libtiff.so.6 \
    && test -e /usr/lib/apache2/modules/mod_ssl.so \
    && test -e /usr/lib/apache2/modules/mod_rewrite.so \
    && test -e /usr/lib/apache2/modules/mod_http2.so \
    && test -e /usr/lib/apache2/modules/mod_mpm_prefork.so \
    && test -e /usr/lib/apache2/modules/mod_security2.so \
    && test -e /usr/lib/apache2/modules/libphp${PHP_VERSION}.so \
    && perl -e 'local $$/=""; @o=(); while(<>){ next if /^Package: (apache2|apache2-bin|apache2-data|apache2-utils|libtiff6)$$/m; push @o, $$_ } print @o' /var/lib/dpkg/status > /tmp/dpkg-status \
    && mv /tmp/dpkg-status /var/lib/dpkg/status \
    && rm -f /var/lib/dpkg/info/apache2.* /var/lib/dpkg/info/apache2-bin.* /var/lib/dpkg/info/apache2-data.* /var/lib/dpkg/info/apache2-utils.* /var/lib/dpkg/info/libtiff6.* /var/lib/dpkg/info/libtiff6:* \
    && for pkg in apache2 apache2-bin apache2-data apache2-utils libtiff6; do \
        if dpkg-query -W "$$pkg" >/dev/null 2>&1; then exit 1; fi; \
    done

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
           /var/www/moodlelocalcache \
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
    && MOODLE_VERSION="${MOODLE_VERSION}" MOODLE_RELEASE_PREFIX="${MOODLE_RELEASE_PREFIX}" \
       bash /scripts/verify-moodle-layout.sh /opt/moodle-source

# Composer: pin security updates past Moodle lockfile.
# - aws/aws-sdk-php: GHSA-27qh-8cxx-2cr5 (need >= 3.371.4)
# - guzzlehttp/guzzle: CVE-2026-69246 (need >= 7.15.2)
# - guzzlehttp/promises: must bump with guzzle (Moodle pins 2.3.0; guzzle 7.15 needs ^2.5.2)
# - guzzlehttp/psr7: guzzle 7.15 needs ^2.13 (Moodle pins 2.8.0)
# - mtdowling/jmespath.php: CVE-2026-54133 (Moodle/aws pin 2.8.0; need >= 2.9.1)
# Without these bumps, `composer require` fails; do not mask with trailing || true.
RUN cd /opt/moodle-source \
    && composer install --no-dev --no-interaction --no-progress --optimize-autoloader \
    && composer require \
           "aws/aws-sdk-php:^3.371.4" \
           "guzzlehttp/guzzle:^7.15.2" \
           "guzzlehttp/promises:^2.5.2" \
           "guzzlehttp/psr7:^2.13" \
           "mtdowling/jmespath.php:^2.9.1" \
           --update-no-dev --no-interaction --no-progress \
           --update-with-all-dependencies \
           --optimize-autoloader \
           --classmap-authoritative \
    && AWS_SDK_VER=$(composer show aws/aws-sdk-php --no-ansi 2>/dev/null | awk '/^versions/{print $NF; exit}') \
    && GUZZLE_VER=$(composer show guzzlehttp/guzzle --no-ansi 2>/dev/null | awk '/^versions/{print $NF; exit}') \
    && JMES_VER=$(composer show mtdowling/jmespath.php --no-ansi 2>/dev/null | awk '/^versions/{print $NF; exit}') \
    && echo "aws/aws-sdk-php=$AWS_SDK_VER guzzlehttp/guzzle=$GUZZLE_VER mtdowling/jmespath.php=$JMES_VER" \
    && php -r "exit(version_compare('${AWS_SDK_VER}', '3.371.4', '<') ? 1 : 0);" \
    && php -r "exit(version_compare('${GUZZLE_VER}', '7.15.2', '<') ? 1 : 0);" \
    && php -r "exit(version_compare('${JMES_VER}', '2.9.1', '<') ? 1 : 0);" \
    && composer clear-cache \
    && rm -rf /root/.composer/cache \
    && { find /opt/moodle-source/vendor -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true; }

# ================================
# Final stage
# ================================
FROM base AS final

# Debian 12 cannot run the Ubuntu 24.04 mariadb:11.8.9 binaries (glibc 2.38).
# Ubuntu 22.04 11.8.9 client debs run here and are not registered with dpkg, so
# Scout does not keep CVE-2026-92262 and CVE-2026-85746 on debian/mariadb.
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

# Health probes, served from outside the Moodle tree so they never go through
# Moodle's wwwroot check. See config/apache/sites/000-default.conf.
COPY --chown=$APP_USER:$APP_GROUP config/health/ /var/www/health/
RUN chmod 0644 /var/www/health/*.php

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

# Ensure permissions for data and log directories.
# /var/www/html must belong to the app user even though the Moodle tree is
# unpacked at runtime: a fresh named volume inherits the ownership of the
# directory it shadows, and the entrypoint runs unprivileged, so leaving it
# root-owned makes `moodle_code:/var/www/html` fail with
# "chown: changing ownership of '/var/www/html': Operation not permitted".
# Drop Debian's default index.html: DocumentRoot is /var/www/html/public, so the
# file is never served, it lands as cruft in the Moodle root, and being
# root-owned it makes the entrypoint's chown fail on a fresh named volume.
RUN rm -f /var/www/html/index.html \
    && chown -R $APP_USER:$APP_GROUP /var/www/html \
    && chmod 775 /var/www/html \
    && chown -R $APP_USER:$APP_GROUP /var/www/moodledata \
    && chmod -R 775 /var/www/moodledata \
    && chown -R $APP_USER:$APP_GROUP /var/www/moodle-backups \
    && chmod -R 775 /var/www/moodle-backups \
    && chown -R $APP_USER:$APP_GROUP /var/www/moodlelocalcache \
    && chmod -R 775 /var/www/moodlelocalcache \
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

# Liveness only: /healthz bypasses Moodle, so it answers 200 no matter what
# $CFG->wwwroot is set to. Load balancers should probe /readyz instead, which
# also verifies the database and drains nodes in maintenance mode.
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=5 \
    CMD curl -fsS -o /dev/null http://localhost:8080/healthz || exit 1

# Entrypoint for container
ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["/scripts/moodle-run.sh"]

