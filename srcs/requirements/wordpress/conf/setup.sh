#!/bin/sh

# Wait for database to be fully ready
echo "Waiting for MariaDB to be fully ready..."
sleep 15

# Create a simple test PHP file
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

# Debug: Print environment variables
echo "Debug: Environment variables:"
echo "WORDPRESS_DB_NAME: ${WORDPRESS_DB_NAME}"
echo "WORDPRESS_DB_USER: ${WORDPRESS_DB_USER}"
echo "WORDPRESS_DB_HOST: ${WORDPRESS_DB_HOST}"
echo "WORDPRESS_DB_CHARSET: ${WORDPRESS_DB_CHARSET}"
echo "WORDPRESS_DB_COLLATE: ${WORDPRESS_DB_COLLATE}"

# Read database password from secret file
DB_PASSWORD=$(cat /run/secrets/db_password 2>/dev/null || echo "default_password")
echo "Debug: DB_PASSWORD: ${DB_PASSWORD}"

# Create wp-config.php using environment variables
if [ ! -f wp-config.php ]; then
    echo "Creating wp-config.php..."
    cat > wp-config.php << EOF
<?php

define('DB_NAME', '${WORDPRESS_DB_NAME:-wordpress_db}');
define('DB_USER', '${WORDPRESS_DB_USER:-wordpress_user}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_HOST', '${WORDPRESS_DB_HOST:-mariadb:3306}');
define('DB_CHARSET', '${WORDPRESS_DB_CHARSET:-utf8}');
define('DB_COLLATE', '${WORDPRESS_DB_COLLATE:-}');

\$table_prefix = 'wp_';

define('WP_DEBUG', false);

if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
EOF
    echo "wp-config.php created successfully!"
else
    echo "wp-config.php already exists"
fi

echo "WordPress setup completed, starting PHP-FPM..."

# Start PHP-FPM
exec "$@"