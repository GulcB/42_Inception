<?php

define('DB_NAME', getenv('MYSQL_DATABASE'));
define('DB_USER', getenv('MYSQL_USER'));
define(
    'DB_PASSWORD',
    trim(file_get_contents('/run/wordpress/db_password'))
);
define('DB_HOST', 'mariadb:3306');

define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

require __DIR__ . '/wp-salts.php';

$table_prefix = 'wp_';

define('WP_HOME', 'https://' . getenv('DOMAIN_NAME'));
define('WP_SITEURL', 'https://' . getenv('DOMAIN_NAME'));

define('DISALLOW_FILE_EDIT', true);

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

require_once ABSPATH . 'wp-settings.php';