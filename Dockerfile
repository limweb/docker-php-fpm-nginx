
FROM php:7.4.0-alpine3.10

LABEL maintainer="Thongchai Lim <limweb@hotmail.com>"

ENV php_conf /usr/local/etc/php-fpm.conf
ENV fpm_conf /usr/local/etc/php-fpm.d/www.conf
ENV php_vars /usr/local/etc/php/conf.d/docker-vars.ini

ENV NGINX_VERSION 1.16.1
ENV LUA_MODULE_VERSION 0.10.14
ENV DEVEL_KIT_MODULE_VERSION 0.3.0
ENV GEOIP2_MODULE_VERSION 3.2
ENV LUAJIT_LIB=/usr/lib
ENV LUAJIT_INC=/usr/include/luajit-2.1

# resolves #166
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php
RUN apk add --no-cache --repository http://dl-3.alpinelinux.org/alpine/edge/community gnu-libiconv

RUN GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
  && CONFIG="\
  --prefix=/etc/nginx \
  --sbin-path=/usr/sbin/nginx \
  --modules-path=/usr/lib/nginx/modules \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx.pid \
  --lock-path=/var/run/nginx.lock \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --user=nginx \
  --group=nginx \
  --with-http_ssl_module \
  --with-http_realip_module \
  --with-http_addition_module \
  --with-http_sub_module \
  --with-http_dav_module \
  --with-http_flv_module \
  --with-http_mp4_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-http_random_index_module \
  --with-http_secure_link_module \
  --with-http_stub_status_module \
  --with-http_auth_request_module \
  --with-http_xslt_module=dynamic \
  --with-http_image_filter_module=dynamic \
  --with-http_geoip_module=dynamic \
  --with-http_perl_module=dynamic \
  --with-threads \
  --with-stream \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-stream_realip_module \
  --with-stream_geoip_module=dynamic \
  --with-http_slice_module \
  --with-mail \
  --with-mail_ssl_module \
  --with-compat \
  --with-file-aio \
  --with-http_v2_module \
  --add-module=/usr/src/ngx_devel_kit-$DEVEL_KIT_MODULE_VERSION \
  --add-module=/usr/src/lua-nginx-module-$LUA_MODULE_VERSION \
  --add-module=/usr/src/ngx_http_geoip2_module-$GEOIP2_MODULE_VERSION \
  " \
  && addgroup -S nginx \
  && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \ 
  && apk add --no-cache --virtual .build-deps \
  autoconf \
  gcc \
  libc-dev \
  make \
  libressl-dev \
  pcre-dev \
  zlib-dev \
  linux-headers \
  curl \
  gnupg \
  libxslt-dev \
  gd-dev \
  geoip-dev \
  libmaxminddb-dev \
  perl-dev \
  luajit-dev \
  && curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
  && curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
  && curl -fSL https://github.com/simpl/ngx_devel_kit/archive/v$DEVEL_KIT_MODULE_VERSION.tar.gz -o ndk.tar.gz \
  && curl -fSL https://github.com/openresty/lua-nginx-module/archive/v$LUA_MODULE_VERSION.tar.gz -o lua.tar.gz \
  && curl -fSL https://github.com/leev/ngx_http_geoip2_module/archive/$GEOIP2_MODULE_VERSION.tar.gz -o ngx_http_geoip2_module.tar.gz \
  && export GNUPGHOME="$(mktemp -d)" \
  && found=''; \
  for server in \
  ha.pool.sks-keyservers.net \
  hkp://keyserver.ubuntu.com:80 \
  hkp://p80.pool.sks-keyservers.net:80 \
  pgp.mit.edu \
  ; do \
  echo "Fetching GPG key $GPG_KEYS from $server"; \
  gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
  done; \
  test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
  gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
  #&& rm -r "$GNUPGHOME" nginx.tar.gz.asc \
  && mkdir -p /usr/src \
  && tar -zxC /usr/src -f nginx.tar.gz \
  && tar -zxC /usr/src -f ndk.tar.gz \
  && tar -zxC /usr/src -f lua.tar.gz \
  && tar -zxC /usr/src -f ngx_http_geoip2_module.tar.gz \
  && rm nginx.tar.gz ndk.tar.gz lua.tar.gz ngx_http_geoip2_module.tar.gz \ 
  && cd /usr/src/nginx-$NGINX_VERSION \
  && ./configure $CONFIG --with-debug \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && mv objs/nginx objs/nginx-debug \
  && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
  && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
  && mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
  && mv objs/ngx_http_perl_module.so objs/ngx_http_perl_module-debug.so \
  && mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
  && ./configure $CONFIG \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && make install \
  && rm -rf /etc/nginx/html/ \
  && mkdir /etc/nginx/conf.d/ \
  && mkdir -p /usr/share/nginx/html/ \
  && install -m644 html/index.html /usr/share/nginx/html/ \
  && install -m644 html/50x.html /usr/share/nginx/html/ \
  && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
  && install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
  && install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
  && install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
  && install -m755 objs/ngx_http_perl_module-debug.so /usr/lib/nginx/modules/ngx_http_perl_module-debug.so \
  && install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
  && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
  && strip /usr/sbin/nginx* \
  && strip /usr/lib/nginx/modules/*.so \
  && rm -rf /usr/src/nginx-$NGINX_VERSION \
  && rm -rf /usr/src/ngx_http_geoip2_module-$GEOIP2_MODULE_VERSION \
  \
  # Bring in gettext so we can get `envsubst`, then throw
  # the rest away. To do this, we need to install `gettext`
  # then move `envsubst` out of the way so `gettext` can
  # be deleted completely, then move `envsubst` back.
  && apk add --no-cache --virtual .gettext gettext \
  && mv /usr/bin/envsubst /tmp/ \
  \
  && runDeps="$( \
  scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
  | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
  | sort -u \
  | xargs -r apk info --installed \
  | sort -u \
  )" \
  && apk add --no-cache --virtual .nginx-rundeps $runDeps \
  && apk del .build-deps \
  && apk del .gettext \
  && mv /tmp/envsubst /usr/local/bin/ \
  \
  # forward request and error logs to docker log collector
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

RUN echo @testing http://nl.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
  echo /etc/apk/respositories && \
  apk update && apk upgrade &&\
  apk add --no-cache \
  bash \
  openssh-client \
  wget \
  supervisor \
  curl \
  libcurl \
  libzip-dev \
  bzip2-dev \
  imap-dev \
  openssl-dev \
  git \
  python3 \
  python3-dev \
  augeas-dev \
  libressl-dev \
  ca-certificates \
  dialog \
  autoconf \
  make \
  gcc \
  musl-dev \
  linux-headers \
  libmcrypt-dev \
  libpng-dev \
  icu-dev \
  libpq \
  libxslt-dev \
  libffi-dev \
  freetype-dev \
  sqlite-dev \
  libjpeg-turbo-dev \
  postgresql-dev && \
  docker-php-ext-configure gd \
  --with-gd \
  --with-freetype-dir=/usr/include/ \
  --with-png-dir=/usr/include/ \
  --with-jpeg-dir=/usr/include/ && \
  #curl iconv session
  #docker-php-ext-install pdo_mysql pdo_sqlite mysqli mcrypt gd exif intl xsl json soap dom zip opcache && \
  docker-php-ext-install iconv pdo_mysql pdo_sqlite pgsql pdo_pgsql mysqli gd exif intl xsl json soap dom zip opcache && \
  pecl install xdebug-2.7.2 && \
  pecl install -o -f redis && \
  echo "extension=redis.so" > /usr/local/etc/php/conf.d/redis.ini && \
  docker-php-source delete && \
  mkdir -p /etc/nginx && \
  mkdir -p /var/www/app && \
  mkdir -p /run/nginx && \
  mkdir -p /var/log/supervisor && \
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
  php composer-setup.php --quiet --install-dir=/usr/bin --filename=composer && \
  rm composer-setup.php && \
  pip3 install -U pip && \
  pip3 install -U certbot && \
  mkdir -p /etc/letsencrypt/webrootauth && \
  apk del gcc musl-dev linux-headers libffi-dev augeas-dev python3-dev make autoconf
#    apk del .sys-deps
#    ln -s /usr/bin/php7 /usr/bin/php

#------------------------------------------------------------------------------------------


LABEL maintainer="Mahmoud Zalt <mahmoud@zalt.me>"


RUN apt-get update \
  && apt-get -y --no-install-recommends install vim openssl libssl-dev wget iputils-ping net-tools apt-utils libxml2-dev gnupg apt-transport-https \
  && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

#
#--------------------------------------------------------------------------
# Mandatory Software's Installation
#--------------------------------------------------------------------------
#
# Mandatory Software's such as ("mcrypt", "pdo_mysql", "libssl-dev", ....)
# are installed on the base image 'laradock/php-fpm' image. If you want
# to add more Software's or remove existing one, you need to edit the
# base image (https://github.com/Laradock/php-fpm).
#

#
#--------------------------------------------------------------------------
# Optional Software's Installation
#--------------------------------------------------------------------------
#
# Optional Software's will only be installed if you set them to `true`
# in the `docker-compose.yml` before the build.
# Example:
#   - INSTALL_ZIP_ARCHIVE=true
#

#####################################
# SOAP:
#####################################

ARG INSTALL_SOAP=true
RUN if [ ${INSTALL_SOAP} = true ]; then \
  # Install the soap extension
  apt-get update -yqq && \
  apt-get -y install libxml2-dev php-soap && \
  docker-php-ext-install soap \
  ;fi

#####################################
# pgsql
#####################################

ARG INSTALL_PGSQL=true
RUN if [ ${INSTALL_PGSQL} = true ]; then \
  # Install the pgsql extension
  apt-get update -yqq && \
  docker-php-ext-install pgsql \
  ;fi

#####################################
# pgsql client
#####################################

ARG INSTALL_PG_CLIENT=true
RUN if [ ${INSTALL_PG_CLIENT} = true ]; then \
  # Create folders if not exists (https://github.com/tianon/docker-brew-debian/issues/65)
  mkdir -p /usr/share/man/man1 && \
  mkdir -p /usr/share/man/man7 && \
  # Install the pgsql client
  apt-get update -yqq && \
  apt-get install -y postgresql-client \
  ;fi

#####################################
# xDebug:
#####################################

ARG INSTALL_XDEBUG=true
RUN if [ ${INSTALL_XDEBUG} = true ]; then \
  # Install the xdebug extension
  # pecl install xdebug && \
  # docker-php-ext-enable xdebug \
  # https://pecl.php.net/get/xdebug-2.8.0beta2.tgz
  cd /tmp && wget https://pecl.php.net/get/xdebug-2.8.0beta2.tgz && \
  tar zxvf xdebug-2.8.0beta2.tgz && \
  cd xdebug-2.8.0beta2  && \
  phpize  && \
  ./configure --enable-xdebug && \
  make && make install && \
  touch /usr/local/etc/php/conf.d/xdebug.ini && \
  echo 'extension=xdebug.so' > /usr/local/etc/php/conf.d/xdebug.ini \
  ;fi
# Copy xdebug configuration for remote debugging
COPY ./xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini



#####################################
# inotify:
#####################################
# https://pecl.php.net/get/inotify-2.0.0.tgz
ARG INSTALL_INOTIFY=true
RUN if [ ${INSTALL_INOTIFY} = true ]; then \
  cd /tmp && wget https://pecl.php.net/get/inotify-2.0.0.tgz && \
  tar zxvf inotify-2.0.0.tgz && \
  cd inotify-2.0.0  && \
  phpize  && \
  ./configure && \
  make && make install && \
  touch /usr/local/etc/php/conf.d/inotify.ini && \
  echo 'extension=inotify.so' > /usr/local/etc/php/conf.d/inotify.ini \
  ;fi


#####################################
# Blackfire:
#####################################

ARG INSTALL_BLACKFIRE=false
RUN if [ ${INSTALL_XDEBUG} = false -a ${INSTALL_BLACKFIRE} = true ]; then \
  version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
  && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/amd64/$version \
  && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp \
  && mv /tmp/blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so \
  && printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707\n" > $PHP_INI_DIR/conf.d/blackfire.ini \
  ;fi

#####################################
# PHP REDIS EXTENSION FOR PHP 7.0
#####################################

ARG INSTALL_PHPREDIS=true
RUN if [ ${INSTALL_PHPREDIS} = true ]; then \
  # unzip -o /tmp/phpredis.zip && mv /tmp/phpredis-* /tmp/phpredis && cd /tmp/phpredis && phpize && ./configure && make && sudo make install
  # https://pecl.php.net/get/redis-5.1.0RC1.tgz
  # Install Php Redis Extension
  # printf "\n" | pecl install -o -f redis \
  # &&  rm -rf /tmp/pear \
  # &&  docker-php-ext-enable redis \
  cd /tmp && wget https://pecl.php.net/get/redis-5.1.0RC1.tgz && \
  tar zxvf redis-5.1.0RC1.tgz && \
  cd redis-5.1.0RC1  && \
  phpize  && \
  ./configure && \
  make && make install && \
  touch /usr/local/etc/php/conf.d/redis.ini && \
  echo 'extension=redis.so' > /usr/local/etc/php/conf.d/redis.ini \

  ;fi

#####################################
# Swoole EXTENSION FOR PHP 7
#####################################

ARG INSTALL_SWOOLE=true
RUN if [ ${INSTALL_SWOOLE} = true ]; then \
  # Install Php Swoole Extension
  # pecl install -f swoole-4.4.6 \
  # &&  docker-php-ext-enable swoole \
  # https://pecl.php.net/get/swoole-4.4.12.tgz

  cd /tmp && wget https://pecl.php.net/get/swoole-4.4.12.tgz && \
  tar zxvf swoole-4.4.12.tgz && \
  cd swoole-4.4.12  && \
  phpize  && \
  ./configure  --enable-openssl && \
  make && make install && \
  touch /usr/local/etc/php/conf.d/swoole.ini && \
  echo 'extension=swoole.so' > /usr/local/etc/php/conf.d/swoole.ini && \
  cd /tmp && wget https://github.com/swoole/ext-async/archive/4.3.2.tar.gz && \
  mv 4.3.2.tar.gz async-ext.tar.gz && tar -zxvf async-ext.tar.gz && \
  cd ext-async-4.3.2/ && \
  phpize && \
  ./configure && make &&  make install && \
  touch /usr/local/etc/php/conf.d/swoole_async.ini && \
  echo 'extension=swoole_async.so' > /usr/local/etc/php/conf.d/swoole_async.ini  \
  ;fi

#####################################
# MongoDB:
# https://pecl.php.net/get/mongodb-1.6.0.tgz
#####################################

ARG INSTALL_MONGO=true
RUN if [ ${INSTALL_MONGO} = true ]; then \
  # Install the mongodb extension
  # pecl install mongodb && \
  cd /tmp && wget https://pecl.php.net/get/mongodb-1.6.0.tgz && \
  tar zxf mongodb-1.6.0.tgz && \
  cd mongodb-1.6.0 && \
  phpize && \
  ./configure --with-php-config=php-config  && \
  make&&make install && \
  echo 'extension=mongodb.so' > /usr/local/etc/php/conf.d/mongodb.ini && \
  docker-php-ext-enable mongodb \
  ;fi

#####################################
# AMQP:
#####################################

ARG INSTALL_AMQP=true
RUN if [ ${INSTALL_AMQP} = true ]; then \
  # apt-get update && \
  # apt-get install librabbitmq-dev -y && \
  # # Install the amqp extension
  # pecl install amqp && \
  # docker-php-ext-enable amqp \
  apt-get update && apt-get install -y cmake librabbitmq-dev && \
  cd /tmp && wget https://github.com/alanxz/rabbitmq-c/archive/v0.9.0.tar.gz && \
  tar xvzf v0.9.0.tar.gz && cd rabbitmq-c-0.9.0 && \
  mkdir build  && cd build && cmake .. && make  && make install  && \
  cd /tmp && wget -c https://pecl.php.net/get/amqp-1.9.4.tgz && \
  tar xvzf amqp-1.9.4.tgz &&   cd ./amqp-1.9.4 && \
  phpize && ./configure --with-amqp  && make && make install && \
  touch /usr/local/etc/php/conf.d/amqp.ini && \  
  echo 'extension=amqp.so' > /usr/local/etc/php/conf.d/amqp.ini \
  ;fi

#####################################
# ZipArchive:
#####################################

ARG INSTALL_ZIP_ARCHIVE=true
RUN if [ ${INSTALL_ZIP_ARCHIVE} = true ]; then \
  # Install the zip extension
  docker-php-ext-install zip \
  ;fi

#####################################
# bcmath:
#####################################

ARG INSTALL_BCMATH=false
RUN if [ ${INSTALL_BCMATH} = true ]; then \
  # Install the bcmath extension
  docker-php-ext-install bcmath \
  ;fi

#####################################
# GMP (GNU Multiple Precision):
#####################################

ARG INSTALL_GMP=false
RUN if [ ${INSTALL_GMP} = true ]; then \
  # Install the GMP extension
  apt-get update -yqq && \
  apt-get install -y libgmp-dev && \
  docker-php-ext-install gmp \
  ;fi

#####################################
# PHP Memcached:
#####################################

ARG INSTALL_MEMCACHED=true
RUN if [ ${INSTALL_MEMCACHED} = true ]; then \
  # Install the php memcached extension
  curl -L -o /tmp/memcached.tar.gz "https://github.com/php-memcached-dev/php-memcached/archive/php7.tar.gz" \
  && mkdir -p memcached \
  && tar -C memcached -zxvf /tmp/memcached.tar.gz --strip 1 \
  && ( \
  cd memcached \
  && phpize \
  && ./configure \
  && make -j$(nproc) \
  && make install \
  ) \
  && rm -r memcached \
  && rm /tmp/memcached.tar.gz \
  && docker-php-ext-enable memcached \
  ;fi

#####################################
# Exif:
#####################################

ARG INSTALL_EXIF=true
RUN if [ ${INSTALL_EXIF} = true ]; then \
  # Enable Exif PHP extentions requirements
  docker-php-ext-install exif \
  ;fi

#####################################
# PHP Aerospike:
#####################################
USER root

ARG INSTALL_AEROSPIKE=false
ENV INSTALL_AEROSPIKE ${INSTALL_AEROSPIKE}

RUN if [ ${INSTALL_AEROSPIKE} = true ]; then \
  # Fix dependencies for PHPUnit within aerospike extension
  apt-get update -yqq && \
  apt-get -y install sudo wget && \
  # Install the php aerospike extension (using 7.2.0-in-progress branch until support for 7.2 on master)
  curl -L -o /tmp/aerospike-client-php.tar.gz "https://github.com/aerospike/aerospike-client-php/archive/7.2.0-in-progress.tar.gz" \
  && mkdir -p aerospike-client-php \
  && tar -C aerospike-client-php -zxvf /tmp/aerospike-client-php.tar.gz --strip 1 \
  && ( \
  cd aerospike-client-php/src \
  && phpize \
  && ./build.sh \
  && make install \
  ) \
  && rm /tmp/aerospike-client-php.tar.gz \
  && docker-php-ext-enable aerospike \
  ;fi

#####################################
# Opcache:
#####################################

ARG INSTALL_OPCACHE=true
RUN if [ ${INSTALL_OPCACHE} = true ]; then \
  docker-php-ext-install opcache \
  ;fi

# Copy opcache configration
COPY ./opcache.ini /usr/local/etc/php/conf.d/opcache.ini

#####################################
# Mysqli Modifications:
#####################################

ARG INSTALL_MYSQLI=false
RUN if [ ${INSTALL_MYSQLI} = true ]; then \
  docker-php-ext-install mysqli \
  ;fi

#####################################
# Tokenizer Modifications:
#####################################

ARG INSTALL_TOKENIZER=false
RUN if [ ${INSTALL_TOKENIZER} = true ]; then \
  docker-php-ext-install tokenizer \
  ;fi

#####################################
# Human Language and Character Encoding Support:
#####################################

ARG INSTALL_INTL=false
RUN if [ ${INSTALL_INTL} = true ]; then \
  # Install intl and requirements
  apt-get update -yqq && \
  apt-get install -y zlib1g-dev libicu-dev g++ && \
  docker-php-ext-configure intl && \
  docker-php-ext-install intl \
  ;fi

#####################################
# GHOSTSCRIPT:
#####################################

ARG INSTALL_GHOSTSCRIPT=false
RUN if [ ${INSTALL_GHOSTSCRIPT} = true ]; then \
  # Install the ghostscript extension
  # for PDF editing
  apt-get update -yqq \
  && apt-get install -y \
  poppler-utils \
  ghostscript \
  ;fi

#####################################
# LDAP:
#####################################

ARG INSTALL_LDAP=true
RUN if [ ${INSTALL_LDAP} = true ]; then \
  apt-get update -yqq && \
  apt-get install -y libldap2-dev && \
  docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
  docker-php-ext-install ldap \
  ;fi

#####################################
# SQL SERVER:
#####################################
ARG INSTALL_MSSQL=true
ENV INSTALL_MSSQL ${INSTALL_MSSQL}
RUN set -eux; if [ ${INSTALL_MSSQL} = true ]; then \
  #####################################
  # Ref from https://github.com/Microsoft/msphpsql/wiki/Dockerfile-for-adding-pdo_sqlsrv-and-sqlsrv-to-official-php-image
  #####################################
  # Add Microsoft repo for Microsoft ODBC Driver 13 for Linux
  # https://pecl.php.net/get/pdo_sqlsrv-5.7.0preview.tgz
  apt-get update -yqq  \
  && apt-get install -y apt-transport-https gnupg \
  && curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
  && curl https://packages.microsoft.com/config/debian/8/prod.list > /etc/apt/sources.list.d/mssql-release.list \
  && apt-get update -yqq \
  # Install Dependencies
  && ACCEPT_EULA=Y apt-get install -y unixodbc unixodbc-dev libgss3 odbcinst msodbcsql locales \
  && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
  && locale-gen \
  # Install pdo_sqlsrv and sqlsrv from PECL. Replace pdo_sqlsrv-4.1.8preview with preferred version.
  # && pecl install pdo_sqlsrv-4.1.8preview sqlsrv-4.1.8preview \
  && cd /tmp && wget https://pecl.php.net/get/pdo_sqlsrv-5.7.0preview.tgz \
  && tar zxf pdo_sqlsrv-5.7.0preview.tgz \
  && cd pdo_sqlsrv-5.7.0preview \
  && phpize \
  && ./configure --with-php-config=php-config \
  && make&&make install \
  && echo 'extension=pdo_sqlsrv.so' > /usr/local/etc/php/conf.d/pdo_sqlsrv.ini \
  && cd /tmp && wget https://pecl.php.net/get/sqlsrv-5.7.0preview.tgz \
  && tar zxf sqlsrv-5.7.0preview.tgz \
  && cd sqlsrv-5.7.0preview \
  && phpize \
  && ./configure --with-php-config=php-config \
  && make&&make install \
  && echo 'extension=sqlsrv.so' > /usr/local/etc/php/conf.d/sqlsrv.ini \
  && php -m | grep -q 'pdo_sqlsrv' \
  && php -m | grep -q 'sqlsrv' \
  ;fi

RUN apt-get update && apt-get install -y unixodbc unixodbc-dev libpq-dev 

RUN set -ex; \
  docker-php-source extract; \
  { \
  echo '# https://github.com/docker-library/php/issues/103#issuecomment-271413933'; \
  echo 'AC_DEFUN([PHP_ALWAYS_SHARED],[])dnl'; \
  echo; \
  cat /usr/src/php/ext/odbc/config.m4; \
  } > temp.m4; \
  mv temp.m4 /usr/src/php/ext/odbc/config.m4; 

RUN apt-get install --no-install-recommends unixodbc unixodbc-dev -y \
  && docker-php-ext-configure odbc --with-unixODBC=shared,/usr

RUN docker-php-ext-configure pdo_odbc --with-pdo-odbc=unixODBC,/usr \
  && docker-php-ext-install odbc pdo_odbc \
  && docker-php-ext-install mysqli pdo_mysql opcache soap 

#####################################
# Image optimizers:
#####################################
USER root
ARG INSTALL_IMAGE_OPTIMIZERS=false
ENV INSTALL_IMAGE_OPTIMIZERS ${INSTALL_IMAGE_OPTIMIZERS}
RUN if [ ${INSTALL_IMAGE_OPTIMIZERS} = true ]; then \
  apt-get update -yqq && \
  apt-get install -y --force-yes jpegoptim optipng pngquant gifsicle \
  ;fi

#####################################
# ImageMagick:
#####################################
USER root
ARG INSTALL_IMAGEMAGICK=false
ENV INSTALL_IMAGEMAGICK ${INSTALL_IMAGEMAGICK}
RUN if [ ${INSTALL_IMAGEMAGICK} = true ]; then \
  apt-get update -y && \
  apt-get install -y libmagickwand-dev imagemagick && \
  pecl install imagick && \
  docker-php-ext-enable imagick \
  ;fi

#####################################
# IMAP:
#####################################
ARG INSTALL_IMAP=false
ENV INSTALL_IMAP ${INSTALL_IMAP}
RUN if [ ${INSTALL_IMAP} = true ]; then \
  apt-get update && \
  apt-get install -y libc-client-dev libkrb5-dev && \
  rm -r /var/lib/apt/lists/* && \
  docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
  docker-php-ext-install imap \
  ;fi

#####################################
# Check PHP version:
#####################################

RUN php -v | head -n 1 | grep -q "PHP 7.2."

#
#--------------------------------------------------------------------------
# Final Touch
#--------------------------------------------------------------------------
#

COPY ./laravel.ini /usr/local/etc/php/conf.d
COPY ./xlaravel.pool.conf /usr/local/etc/php-fpm.d/

#RUN rm -r /var/lib/apt/lists/*
RUN docker-php-source delete \
  && apt-get purge --auto-remove -y g++ \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/*

RUN usermod -u 1000 www-data

WORKDIR /var/www

#------------------------------------------------------------------------------------------

ADD conf/supervisord.conf /etc/supervisord.conf

# Copy our nginx config
RUN rm -Rf /etc/nginx/nginx.conf
ADD conf/nginx.conf /etc/nginx/nginx.conf

# nginx site conf
RUN mkdir -p /etc/nginx/sites-available/ && \
  mkdir -p /etc/nginx/sites-enabled/ && \
  mkdir -p /etc/nginx/ssl/ && \
  rm -Rf /var/www/* && \
  mkdir /var/www/html/
ADD conf/nginx-site.conf /etc/nginx/sites-available/default.conf
ADD conf/nginx-site-ssl.conf /etc/nginx/sites-available/default-ssl.conf
RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

# Add GeoLite2 databases (https://dev.maxmind.com/geoip/geoip2/geolite2/)
RUN curl -fSL http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz -o /etc/nginx/GeoLite2-City.mmdb.gz \
  && curl -fSL http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.mmdb.gz -o /etc/nginx/GeoLite2-Country.mmdb.gz \
  && gunzip /etc/nginx/GeoLite2-City.mmdb.gz \
  && gunzip /etc/nginx/GeoLite2-Country.mmdb.gz

# tweak php-fpm config
RUN echo "cgi.fix_pathinfo=0" > ${php_vars} &&\
  echo "upload_max_filesize = 100M"  >> ${php_vars} &&\
  echo "post_max_size = 100M"  >> ${php_vars} &&\
  echo "variables_order = \"EGPCS\""  >> ${php_vars} && \
  echo "memory_limit = 128M"  >> ${php_vars} && \
  sed -i \
  -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" \
  -e "s/pm.max_children = 5/pm.max_children = 4/g" \
  -e "s/pm.start_servers = 2/pm.start_servers = 3/g" \
  -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" \
  -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" \
  -e "s/;pm.max_requests = 500/pm.max_requests = 200/g" \
  -e "s/user = www-data/user = nginx/g" \
  -e "s/group = www-data/group = nginx/g" \
  -e "s/;listen.mode = 0660/listen.mode = 0666/g" \
  -e "s/;listen.owner = www-data/listen.owner = nginx/g" \
  -e "s/;listen.group = www-data/listen.group = nginx/g" \
  -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g" \
  -e "s/^;clear_env = no$/clear_env = no/" \
  ${fpm_conf}
#    ln -s /etc/php7/php.ini /etc/php7/conf.d/php.ini && \
#    find /etc/php7/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;


# Add Scripts
ADD scripts/start.sh /start.sh
ADD scripts/pull /usr/bin/pull
ADD scripts/push /usr/bin/push
ADD scripts/letsencrypt-setup /usr/bin/letsencrypt-setup
ADD scripts/letsencrypt-renew /usr/bin/letsencrypt-renew
RUN chmod 755 /usr/bin/pull && chmod 755 /usr/bin/push && chmod 755 /usr/bin/letsencrypt-setup && chmod 755 /usr/bin/letsencrypt-renew && chmod 755 /start.sh

# copy in code
ADD src/ /var/www/html/
ADD errors/ /var/www/errors


EXPOSE 443 80

WORKDIR "/var/www/html"
CMD ["/start.sh"]
