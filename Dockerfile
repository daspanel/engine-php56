FROM daspanel/alpine-base
MAINTAINER Abner G Jacobsen - http://daspanel.com <admin@daspanel.com>

# Parse arguments for the build command.
ARG VERSION
ARG VCS_URL
ARG VCS_REF
ARG BUILD_DATE

# Set default env variables
ENV \
    # Stop container initialization if error occurs in cont-init.d, fix-attrs.d script's
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \

    # Timezone
    TZ="UTC" 

# A little bit of metadata management.
# See http://label-schema.org/  
LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.version=$VERSION \
      org.label-schema.vcs-url=$VCS_URL \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.name="daspanel/engine-php56" \
      org.label-schema.description="This service provides HTTP static engine daemon to Daspanel."

# PHP modules to install
ARG PHP_MODULES="php5-ctype php5-curl php5-dom php5-gd php5-iconv php5-intl \
    php5-json php5-mcrypt php5-memcache php5-mysql php5-mysqli php5-openssl \
    php5-pdo php5-pdo_mysql php5-pdo_pgsql php5-pdo_sqlite php5-pear \
    php5-pgsql php5-phar php5-sqlite3 php5-xml php5-zip php5-zlib \
    php5-pcntl php5-ftp php5-gettext php5-imap php5-bcmath php5-posix \
    php5-soap php5-xmlreader php5-bz2 php5-exif \
    php5-gmp php5-imagick php5-apcu php5-opcache php5-sockets php5-pspell"

ARG CADDY_PLUGINS="http.cors,http.expires,http.ipfilter,http.ratelimit,http.realip,tls.dns.cloudflare,tls.dns.digitalocean,tls.dns.linode,tls.dns.route53"
ARG CADDY_URL="https://caddyserver.com/download/linux/amd64?plugins=${CADDY_PLUGINS}"

RUN apk --update --no-cache add --virtual build_deps curl && \
    apk add --no-cache --update libcap mailcap php5 php5-fpm php5-cli $PHP_MODULES && \
    curl -sS https://getcomposer.org/installer \
        | php -- --install-dir=/usr/bin --filename=composer && \
    curl --silent --show-error --fail --location \
      --header "Accept: application/tar+gzip, application/x-gzip, application/octet-stream" -o - \
      "${CADDY_URL}" \
    | tar --no-same-owner -C /usr/sbin/ -xz caddy && \
    chmod 0755 /usr/sbin/caddy && \
    setcap "cap_net_bind_service=+ep" /usr/sbin/caddy && \
    apk del build_deps && \
    rm -rf \
        /var/cache/apk/* \
        /tmp/src \
        /tmp/*

# Inject files in container file system
COPY rootfs /

# Expose ports for the service
EXPOSE 443






