FROM debian:bookworm-slim

ARG WORDPRESS_VERSION=7.1.5
ARG WP_CLI_VERSION=2.12.0

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends \
        ca-certificates \
        curl \
        util-linux \
        php8.2-cli \
        php8.2-fpm \
        php8.2-mysql \
        php8.2-curl \
        php8.2-gd \
        php8.2-mbstring \
        php8.2-xml \
        php8.2-zip \
        php8.2-intl \
    && rm -rf /var/lib/apt/lists/* \
    && install -d -o www-data -g www-data /run/php /var/www/html \
    && install -d /usr/local/share/inception \
    && curl -fsSL \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
        -o /usr/local/bin/wp \
    && curl -fsSL \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar.sha512" \
        -o /tmp/wp-cli.sha512 \
    && printf '%s  %s\n' \
        "$(awk 'NR==1 {print $1}' /tmp/wp-cli.sha512)" \
        /usr/local/bin/wp | sha512sum -c - \
    && chmod 0755 /usr/local/bin/wp \
    && rm /tmp/wp-cli.sha512 \
    && wp core download \
        --version="${WORDPRESS_VERSION}" \
        --locale=en_US \
        --path=/usr/src/wordpress \
        --allow-root

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY conf/wp-config.php /usr/local/share/inception/wp-config.php
COPY tools/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm8.2", "-F"]