# Multi-stage build for optimization
FROM debian:12-slim AS base

ARG MOODLE_VERSION=5.0.1
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

# Enterprise labels - positioned early for metadata availability
LABEL org.opencontainers.image.title="ABS Premium LMS powered by Moodle™ LMS" \
      org.opencontainers.image.description="Enterprise-grade Moodle LMS with security hardening, performance optimization, and premium support by ABSI Technology" \
      org.opencontainers.image.version="5.0.1" \
      org.opencontainers.image.vendor="ABS Technology Joint Stock Company" \
      org.opencontainers.image.authors="ABS Technology <support@absi.edu.vn>" \
      org.opencontainers.image.url="https://abs.education" \
      org.opencontainers.image.documentation="https://docs.abs.education/" \
      org.opencontainers.image.source="https://github.com/absi-tech/moodle-premium" \
      org.opencontainers.image.created="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
      org.opencontainers.image.base.name="docker.io/library/debian:12-slim" \
      maintainer="ABSI Technology <support@absi.edu.vn>" \
      \
      # Security & Compliance labels
      security.scan.compliant="true" \
      security.hardened="true" \
      compliance.level="enterprise" \
      compliance.standards="ISO27001,SOC2,GDPR" \
      \
      # Technical specifications
      platform.php.version="8.4" \
      platform.apache.version="2.4" \
      platform.moodle.version="5.0.1" \
      platform.database.supported="MariaDB,MySQL,PostgreSQL" \
      \
      # Enterprise features
      enterprise.support="24/7" \
      enterprise.sla="99.9%" \
      enterprise.backup="automated" \
      enterprise.monitoring="included" \
      enterprise.updates="managed" \
      \
      # Company branding
      company.name="ABS Technology Joint Stock Company" \
      company.website="https://abs.education" \
      company.email="support@absi.edu.vn" \
      company.phone="+84 0933 688 088" \
      company.address="Ho Chi Minh City, Vietnam" \
      \
      # Build information
      build.tool="Docker Buildx" \
      build.multi-arch="true" \
      build.attestations="true" \
      build.sbom="included"

# Add Sury repository for latest PHP versions
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    lsb-release \
    wget \
    && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
    && apt-get update \
    && apt-get upgrade -y

# Gói cài đặt: Apache, PHP-FPM, PHP CLI, MariaDB/MySQL client, các module PHP cần thiết
# Đảm bảo cài đặt đủ các dependency
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
    cron \
    locales \
    mariadb-client \
    curl \
    acl \
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
RUN groupadd -g $APP_GID $APP_GROUP && \
    useradd -u $APP_UID -g $APP_GROUP -m -s /bin/bash $APP_USER

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

# Copy các script đã tinh gọn
COPY scripts/entrypoint.sh /scripts/entrypoint.sh
COPY scripts/moodle-run.sh /scripts/moodle-run.sh
COPY scripts/setup/ /scripts/setup/
COPY scripts/lib/ /scripts/lib/
COPY scripts/post-init.d/ /docker-entrypoint-init.d/

# ================================
# Moodle source stage (from local source)
# ================================
FROM base AS moodle-source

# Copy local Moodle source instead of downloading
COPY source/moodle /opt/moodle-source
RUN find /opt/moodle-source -type d -exec chmod 755 {} + \
    && find /opt/moodle-source -type f -exec chmod 644 {} +

# ================================
# Final stage
# ================================
FROM base AS final

# Copy Moodle source from moodle-source stage to init location
COPY --from=moodle-source --chown=$APP_USER:$APP_GROUP /opt/moodle-source /opt/moodle-source

# Copy database dump and moodledata for initialization
RUN mkdir -p /opt/moodle-init
COPY source/moodle_db.sql /opt/moodle-init/moodle_db.sql
COPY source/moodledata /opt/moodle-init/moodledata
RUN chown -R $APP_USER:$APP_GROUP /opt/moodle-init

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

# Set permissions cho config directories và files để non-root user có thể modify runtime
RUN chown -R $APP_USER:$APP_GROUP /etc/apache2 \
    && chown -R $APP_USER:$APP_GROUP /etc/php/${PHP_VERSION}/fpm \
    && chown -R $APP_USER:$APP_GROUP /etc/ssl/certs \
    && chown -R $APP_USER:$APP_GROUP /etc/ssl/private \
    && chown $APP_USER:$APP_GROUP /var/run
RUN rm -f /etc/php/${PHP_VERSION}/cli/php.ini \
    && ln -s /etc/php/${PHP_VERSION}/fpm/php.ini /etc/php/${PHP_VERSION}/cli/php.ini

# Cấu hình log của Apache và PHP-FPM ra stdout/stderr
RUN ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log \
    && ln -sf /dev/stdout /var/log/apache2/other_vhosts_access.log \
    && ln -sf /dev/stdout /var/log/php${PHP_VERSION}-fpm.log

# Đảm bảo quyền cho các thư mục dữ liệu và log
RUN chown -R $APP_USER:$APP_GROUP /var/www/moodledata \
    && chmod -R 775 /var/www/moodledata \
    && chown -R $APP_USER:$APP_GROUP /var/run/php \
    && chmod -R 775 /var/run/php \
    && chown -R $APP_USER:$APP_GROUP /scripts \
    && find /scripts -type f -exec chmod +x {} + \
    && find /docker-entrypoint-init.d/ -type f -exec chmod +x {} +

WORKDIR /var/www/html
# Create user and add to crontab group for cron job permissions
RUN groupadd -g $APP_GID $APP_GROUP || true \
    && useradd -u $APP_UID -g $APP_GID -m -s /bin/bash $APP_USER || true \
    && usermod -a -G crontab $APP_USER

# Switch to non-root user for security
USER $APP_USER

# Expose non-privileged ports for non-root user
EXPOSE 8080 8443

# Entrypoint cho container
ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["/scripts/moodle-run.sh"]

