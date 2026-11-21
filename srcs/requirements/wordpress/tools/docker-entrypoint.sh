#!/bin/sh
set -eu

if [ "${1:-}" != "php-fpm8.2" ]; then
    exec "$@"
fi

: "${DOMAIN_NAME:?DOMAIN_NAME is required}"
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"
: "${WP_SITE_TITLE:?WP_SITE_TITLE is required}"
: "${WP_ADMIN_USER:?WP_ADMIN_USER is required}"
: "${WP_ADMIN_EMAIL:?WP_ADMIN_EMAIL is required}"
: "${WP_USER:?WP_USER is required}"
: "${WP_USER_EMAIL:?WP_USER_EMAIL is required}"

case "$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')" in
    *admin*)
        echo "Administrator username must not contain admin" >&2
        exit 1
        ;;
esac

if [ "$WP_ADMIN_USER" = "$WP_USER" ]; then
    echo "WordPress usernames must differ" >&2
    exit 1
fi

for secret in db_password wp_admin_password wp_user_password; do
    if [ ! -s "/run/secrets/$secret" ]; then
        echo "Missing or empty secret: $secret" >&2
        exit 1
    fi
done

install -d -o www-data -g www-data -m 0700 /run/wordpress

cp /run/secrets/db_password /run/wordpress/db_password
chown www-data:www-data /run/wordpress/db_password
chmod 0600 /run/wordpress/db_password

if [ ! -f /var/www/html/wp-includes/version.php ]; then
    echo "Copying WordPress core..."
    cp -a /usr/src/wordpress/. /var/www/html/
fi

if [ ! -f /var/www/html/wp-config.php ]; then
    cp /usr/local/share/inception/wp-config.php \
        /var/www/html/wp-config.php
fi

if [ ! -f /var/www/html/wp-salts.php ]; then
    (
        umask 077
        printf '%s\n' '<?php'

        for key in \
            AUTH_KEY \
            SECURE_AUTH_KEY \
            LOGGED_IN_KEY \
            NONCE_KEY \
            AUTH_SALT \
            SECURE_AUTH_SALT \
            LOGGED_IN_SALT \
            NONCE_SALT
        do
            printf "define('%s', '%s');\n" \
                "$key" \
                "$(php -r 'echo bin2hex(random_bytes(48));')"
        done
    ) > /var/www/html/wp-salts.php
fi

chown -R www-data:www-data /var/www/html
chmod 0640 \
    /var/www/html/wp-config.php \
    /var/www/html/wp-salts.php

if ! runuser -u www-data -- wp core is-installed --quiet; then
    echo "Installing WordPress..."

    runuser -u www-data -- wp core install \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_SITE_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --prompt=admin_password < /run/secrets/wp_admin_password
fi

if ! runuser -u www-data -- \
    wp user get "$WP_USER" --field=ID > /dev/null 2>&1
then
    runuser -u www-data -- wp user create \
        "$WP_USER" "$WP_USER_EMAIL" \
        --role=author \
        --porcelain \
        --prompt=user_pass \
        < /run/secrets/wp_user_password > /dev/null

    echo "Secondary WordPress user created."
fi

echo "WordPress initialization completed."

exec "$@"