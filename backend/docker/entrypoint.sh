#!/bin/sh
set -eu

APP_DIR=/var/www/html
PORT_VALUE="${PORT:-80}"

cd "$APP_DIR"

sed "s/__PORT__/${PORT_VALUE}/g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache

chown -R www-data:www-data storage bootstrap/cache

if [ -z "${APP_KEY:-}" ] && [ ! -f .env ]; then
    echo "APP_KEY is not set. Provide it through Render environment variables or an .env file." >&2
fi

if [ "${LARAVEL_CACHE_AT_STARTUP:-true}" = "true" ]; then
    rm -f bootstrap/cache/config.php bootstrap/cache/events.php
    rm -f bootstrap/cache/routes-*.php
    rm -f storage/framework/views/*
    su-exec www-data php artisan config:cache
    su-exec www-data php artisan route:cache
    su-exec www-data php artisan view:cache
fi

if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
    echo "Running database migrations..."
    su-exec www-data php artisan migrate --force
fi

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf