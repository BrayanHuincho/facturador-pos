FROM php:8.3-cli-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends libxml2-dev libzip-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev libwebp-dev unzip curl ca-certificates tzdata openssl \
 && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
 && docker-php-ext-install soap zip gd \
 && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

ENV TZ=America/Lima \
    PHP_CLI_SERVER_WORKERS=4 \
    COMPOSER_ALLOW_SUPERUSER=1

RUN printf "date.timezone=America/Lima\nmemory_limit=256M\nmax_execution_time=90\ndefault_socket_timeout=40\nexpose_php=Off\ndisplay_errors=Off\nlog_errors=On\nzend.exception_ignore_args=On\n" > /usr/local/etc/php/conf.d/servicio.ini

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --no-progress --prefer-dist --no-scripts --no-autoloader

COPY src ./src
COPY public ./public
COPY plantillas ./plantillas
COPY scripts ./scripts
RUN composer dump-autoload --optimize --no-dev \
 && chmod +x scripts/generar-certificado-prueba.sh \
 && mkdir -p /tmp/greenter certificados \
 && chown -R www-data:www-data /tmp/greenter certificados

USER www-data
EXPOSE 4210

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://127.0.0.1:4210/salud || exit 1

CMD ["sh", "-c", "scripts/generar-certificado-prueba.sh && exec php -S 0.0.0.0:4210 -t public public/index.php"]
