FROM golang:1.9-alpine3.6 as builder-caddy
LABEL maintainer="ulrich.schreiner@gmail.com"

ENV CADDY_VERSION v0.10.10

# Inject files in container file system
COPY caddy-build /caddy-build

RUN apk --no-cache update \
    && apk --no-cache --update add git bash \
    && cd /caddy-build \
    && env OS=linux ARCH=amd64 ./build_caddy.sh \
    && ls -la /caddy-build/caddy

FROM daspanel/engine-base-dev:dev
MAINTAINER Abner G Jacobsen - http://daspanel.com <admin@daspanel.com>

# Thanks:
#   https://github.com/openbridge/ob_php-fpm

# Copy bynaries build before
COPY --from=builder-caddy /caddy-build/caddy /usr/sbin/caddy

# Parse Daspanel common arguments for the build command.
ARG VERSION
ARG VCS_URL
ARG VCS_REF
ARG BUILD_DATE
ARG S6_OVERLAY_VERSION=v1.19.1.1
ARG DASPANEL_IMG_NAME=engine-php56
ARG DASPANEL_OS_VERSION=alpine3.6

# Parse Container specific arguments for the build command.
ARG GOTTY_URL="https://github.com/yudai/gotty/releases/download/v2.0.0-alpha.3/gotty_2.0.0-alpha.3_linux_amd64.tar.gz"
ARG WP_CLI_VERSION="1.4.1"
ARG WPCLI_URL="https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar"

# PHP minimal modules to install - run's Worpress, Grav and others
ARG PHP_MINIMAL="php5-fpm php5 php5-cli php5-common php5-pear php5-phar php5-posix \
    php5-ctype php5-iconv php5-bcmath php5-bz2 php5-calendar \
    php5-gettext php5-pspell php5-gmp \
    php5-zip php5-zlib php5-intl php5-mcrypt \ 
    php5-json php5-dom php5-soap php5-xsl php5-xml \
         php5-xmlreader \
    php5-curl php5-openssl php5-sockets php5-imap php5-ftp \
    php5-mysqli \
    php5-pdo php5-pdo_mysql php5-pdo_pgsql php5-pdo_sqlite \
    php5-exif php5-gd \
    php5-opcache php5-pcntl"

ARG PECL_MINIMAL="yaml-2.0.0"

ARG PHP_MODULES="php5-pgsql php5-sqlite3 \
    php5-enchant \
    php5-ldap \
    php5-pdo_dblib"
    
ARG PHP_MODULES_EXTRA=""

ARG PHP_XDEBUG=""
ARG PHP_PHPDBG="php5-phpdbg"

ARG PHP_MODULES_BANNED="php5-sysvsem php5-sysvshm php5-xmlrpc php5-shmop \
    php5-snmp php5-sysvmsg php5-odbc php5-pdo_odbc php5-ldap php5-apache2 \
    php5-cgi php5-dba php5-embed php5-litespeed php5-doc"

# Set default env variables
ENV \
    # Stop container initialization if error occurs in cont-init.d, fix-attrs.d script's
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \

    # Timezone
    TZ="UTC" \

    # DASPANEL defaults
    DASPANEL_WAIT_FOR_API="YES"

# A little bit of metadata management.
# See http://label-schema.org/  
LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.version=$VERSION \
      org.label-schema.vcs-url=$VCS_URL \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.name="daspanel/engine-php56" \
      org.label-schema.description="This service provides HTTP php 5.6 engine server to Daspanel sites."

ENV TERM=xterm-256color
ENV VAR_PREFIX=/var/run
ENV LOG_PREFIX=/var/log/php-fpm5
ENV TEMP_PREFIX=/tmp
ENV CACHE_PREFIX=/var/cache

# Solves: https://github.com/wp-cli/wp-cli/issues/4246#issuecomment-325774849
# less: unrecognized option: r
# BusyBox v1.26.2 (2017-06-11 06:38:32 GMT) multi-call binary.
ENV PAGER='more' 

# Inject files in container file system
COPY rootfs /

RUN set -x \

    # Initial OS bootstrap - required
    && sh /opt/daspanel/bootstrap/${DASPANEL_OS_VERSION}/00_base \

    # Install Daspanel base - common layer for all container's independent of the OS and init system
    && wget -O /tmp/opt-daspanel.zip "https://github.com/daspanel/rootfs-base/releases/download/0.1.0/opt-daspanel.zip" \
    && unzip -o -d / /tmp/opt-daspanel.zip \

    # Install Daspanel bootstrap for Alpine Linux with S6 Overlay Init system
    && wget -O /tmp/alpine-s6.zip "https://github.com/daspanel/rootfs-base/releases/download/0.1.0/alpine-s6.zip" \
    && unzip -o -d / /tmp/alpine-s6.zip \

    # Bootstrap the system (TBD)

    # Install s6 overlay init system
    && wget https://github.com/just-containers/s6-overlay/releases/download/$S6_OVERLAY_VERSION/s6-overlay-amd64.tar.gz --no-check-certificate -O /tmp/s6-overlay.tar.gz \
    && tar xvfz /tmp/s6-overlay.tar.gz -C / \
    && rm -f /tmp/s6-overlay.tar.gz \

    # ensure www-data user exists
    && addgroup -g 82 -S www-data \
    && adduser -u 82 -D -S -h /home/www-data -s /sbin/nologin -G www-data www-data \

    # Install specific OS packages needed by this image
    && sh /opt/daspanel/bootstrap/${DASPANEL_OS_VERSION}/99_install_pkgs "git" \

    # Install PHP and modules avaiable on the default repositories of this Linux distro
    && sh /opt/daspanel/bootstrap/${DASPANEL_OS_VERSION}/99_install_pkgs "${PHP_MINIMAL}" \
    && sh /opt/daspanel/bootstrap/${DASPANEL_OS_VERSION}/99_install_pkgs "${PHP_MODULES}" \
    && sh /opt/daspanel/bootstrap/${DASPANEL_OS_VERSION}/99_install_pkgs "${PHP_MODULES_EXTRA}" \
    && sh /opt/daspanel/bootstrap/${DASPANEL_OS_VERSION}/99_install_pkgs "${PHP_PHPDBG}" \
    && sh /opt/daspanel/bootstrap/${DASPANEL_OS_VERSION}/99_install_pkgs "${PHP_XDEBUG}" \

    # In Alpine 3.6 PHP 5.6 install don't create /usr/bin/php
    && ln -sf /usr/bin/php5 /usr/bin/php \

    # Install PHP Composer
    && curl -sS https://getcomposer.org/installer | php5 -- --install-dir=/usr/local/bin --filename=composer \

    # Install PHPUnit
    && curl -sSL https://phar.phpunit.de/phpunit-6.2.phar -o /usr/local/bin/phpunit \
    && chmod +x /usr/local/bin/phpunit \

    # PECL fix
    # Bug Fix: 
    # https://serverfault.com/questions/589877/pecl-command-produces-long-list-of-errors
    # https://bugs.alpinelinux.org/issues/5378
    # Patch pecl command
    && sed -i -e 's/\(PHP -C\) -n/\1/g' /usr/bin/pecl \
    && mkdir -p /tmp/pear/cache \

    # Cleanup after phpizing
    #&& rm -rf /usr/include/php5 /usr/lib/php5/build \

    # Install wp-cli
    && curl --progress-bar --show-error --fail --location \
        --header "Accept: application/tar+gzip, application/x-gzip, application/octet-stream" -o /usr/local/bin/wp \
        "${WPCLI_URL}" \
    && chmod 0755 /usr/local/bin/wp \

    # Install gotty
    && curl --progress-bar --show-error --fail --location \
        --header "Accept: application/tar+gzip, application/x-gzip, application/octet-stream" -o /tmp/gotty.tar.gz \
        "${GOTTY_URL}" \
    && tar -C /usr/sbin -xvzf /tmp/gotty.tar.gz \
    && chmod 0755 /usr/sbin/gotty \
    && mkdir /lib64 \
    && ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2 \
    && rm /tmp/gotty.tar.gz \

    # Install Caddy
    && chmod 0755 /usr/sbin/caddy \
    && setcap "cap_net_bind_service=+ep" /usr/sbin/caddy \

    # Cleanup
    && rm -rf /tmp/* \
    && rm -rf /var/cache/apk/*

# Let's S6 control the init system
ENTRYPOINT ["/init"]
CMD []

# Expose ports for the service
EXPOSE 443

