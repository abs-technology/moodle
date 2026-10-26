ARG BASE_IMAGE=debian:13-slim@sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad
FROM ${BASE_IMAGE} AS base

ARG MOODLE_VERSION=5.3.0
ARG MOODLE_RELEASE_PREFIX=5.3
ARG MOODLE_DOWNLOAD_URL=https://packaging.moodle.org/stable503/moodle-5.3.tgz
ARG MOODLE_TGZ_SHA256=7e5edf110555956571f40e42acffde0eb23681ebebd212a2fec0fe7d795dd511
ARG PHP_VERSION=8.4
ARG PHP_RELEASE=8.4.27
ARG COMPOSER_VERSION=2.8.12
ARG COMPOSER_SHA256=f446ea719708bb85fcbf4ef18def5d0515f1f9b4d703f6d820c9c1656e10a2f2
ARG SURY_PHP_GPG_SHA256=b486fd5488185c4c46467960fa69c53d5085fec492cf76b9eaf3db33561c9d7c
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

# debian:13-slim already has trixie + trixie-security (DEB822). Do not append
# a bookworm-security line — that would mix Debian 12 packages into this image.
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    lsb-release \
    wget \
    gnupg2 \
    && wget -O /tmp/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "${SURY_PHP_GPG_SHA256}  /tmp/php.gpg" | sha256sum -c - \
    && mv /tmp/php.gpg /etc/apt/trusted.gpg.d/php.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
    && printf 'Package: php%s*\nPin: version %s*\nPin-Priority: 1001\n\nPackage: libapache2-mod-php%s\nPin: version %s*\nPin-Priority: 1001\n' \
        "$PHP_VERSION" "$PHP_RELEASE" "$PHP_VERSION" "$PHP_RELEASE" \
        > /etc/apt/preferences.d/php-release \
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
    libedit2 \
    libncurses6 \
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

# trixie ships libssl3t64, not libssl3. A full upgrade picks the current names.
RUN apt-get update \
    && apt-get upgrade -y \
    && test "$(php -r 'echo PHP_VERSION;')" = "$PHP_RELEASE" \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Security: Remove unnecessary packages and clean up
RUN apt-get autoremove -y \
    && apt-get autoclean -y

# Install Composer from a pinned phar. Do not pipe the installer to php.
ARG COMPOSER_VERSION
ARG COMPOSER_SHA256
RUN curl -fsSL -o /tmp/composer.phar "https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar" \
    && echo "${COMPOSER_SHA256}  /tmp/composer.phar" | sha256sum -c - \
    && install -m 0755 /tmp/composer.phar /usr/local/bin/composer \
    && rm -f /tmp/composer.phar

# Configure locale for UTF-8 support
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Enable PHP extensions

RUN phpenmod mysqli pdo pdo_mysql opcache apcu imagick \
    && php -r 'exit(extension_loaded("sodium") ? 0 : 1);'

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
ARG MOODLE_TGZ_SHA256

RUN curl -fsSL "${MOODLE_DOWNLOAD_URL}" -o /tmp/moodle.tgz \
    && echo "${MOODLE_TGZ_SHA256}  /tmp/moodle.tgz" | sha256sum -c - \
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

# Client binaries from the official server image. Debian's mariadb packages stay
# flagged by Scout for CVE-2026-92262 and CVE-2026-85746 (no fixed trixie version),
# including 11.8.9 from dlm.mariadb.com. These two binaries are the 11.8.9 client
# and are not registered as a Debian package. SQL still goes through PHP mysqli.
ARG MARIADB_IMAGE=mariadb:11.8.9@sha256:f16d7a344413e519dff518f27bdb221388f84b0d274c97c4fb5f2cb0dc1b34fa
FROM ${MARIADB_IMAGE} AS mariadb-client

# ================================
# Final stage
# ================================
FROM base AS final

COPY --from=mariadb-client /usr/bin/mariadb-dump /usr/local/bin/mariadb-dump
COPY --from=mariadb-client /usr/bin/mariadb /usr/local/bin/mariadb
RUN ln -sf mariadb /usr/local/bin/mysql \
    && ln -sf mariadb-dump /usr/local/bin/mysqldump \
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

# App user may rewrite Apache/PHP config at boot. It must not own the
# CA store or the private-key directory — only the generated site cert.
RUN chown -R $APP_USER:$APP_GROUP /etc/apache2 \
    && chown -R $APP_USER:$APP_GROUP /etc/php/${PHP_VERSION}/fpm \
    && chown -R $APP_USER:$APP_GROUP /etc/php/${PHP_VERSION}/apache2 \
    && chown root:$APP_GROUP /etc/ssl/private \
    && chmod 750 /etc/ssl/private \
    && chown $APP_USER:$APP_GROUP /etc/ssl/certs/localhost.crt /etc/ssl/private/localhost.key \
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

