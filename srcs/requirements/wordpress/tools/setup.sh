#!/bin/sh

# Wait for database to be fully ready
echo "Waiting for MariaDB to be fully ready..."
sleep 15

# Read database password from secret file
DB_PASSWORD=$(cat /run/secrets/db_password)

# Create wp-config.php using environment variables and secrets
if [ ! -f wp-config.php ]; then
    echo "Creating wp-config.php..."
    
    # Read database password from secret file
    DB_PASSWORD=$(cat /run/secrets/db_password)
    
    cat > wp-config.php << EOF
<?php

define('DB_NAME', '${WORDPRESS_DB_NAME}');
define('DB_USER', '${WORDPRESS_DB_USER}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_HOST', '${WORDPRESS_DB_HOST}');
define('DB_CHARSET', '${WORDPRESS_DB_CHARSET}');
define('DB_COLLATE', '${WORDPRESS_DB_COLLATE}');

\$table_prefix = 'wp_';

define('AUTH_KEY',         '${WP_AUTH_KEY}');
define('SECURE_AUTH_KEY',  '${WP_SECURE_AUTH_KEY}');
define('LOGGED_IN_KEY',    '${WP_LOGGED_IN_KEY}');
define('NONCE_KEY',        '${WP_NONCE_KEY}');
define('AUTH_SALT',        '${WP_AUTH_SALT}');
define('SECURE_AUTH_SALT', '${WP_SECURE_AUTH_SALT}');
define('LOGGED_IN_SALT',   '${WP_LOGGED_IN_SALT}');
define('NONCE_SALT',       '${WP_NONCE_SALT}');

define('WP_DEBUG', false);

if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
EOF
    echo "wp-config.php created successfully!"
fi

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
while ! nc -z mariadb 3306; do
    echo "MariaDB not ready, waiting..."
    sleep 3
done

# Give MariaDB a bit more time to fully initialize
sleep 5

# Test database connection with mysql client
echo "Testing database connection..."
while ! mysql -h mariadb -u ${WORDPRESS_DB_USER} -p${DB_PASSWORD} -e "USE ${WORDPRESS_DB_NAME};" 2>/dev/null; do
    echo "Database connection not ready, waiting..."
    sleep 3
done

echo "Database connection successful!"

# Check if WordPress is already installed by checking if wp_options table exists and has data
TABLES_COUNT=$(mysql -h mariadb -u ${WORDPRESS_DB_USER} -p${DB_PASSWORD} -e "USE ${WORDPRESS_DB_NAME}; SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${WORDPRESS_DB_NAME}';" 2>/dev/null | tail -1)

if [ "$TABLES_COUNT" -lt "12" ]; then
    echo "Installing WordPress (found $TABLES_COUNT tables, need 12)..."
    
    # First, drop any existing tables to start fresh
    mysql -h mariadb -u ${WORDPRESS_DB_USER} -p${DB_PASSWORD} -e "
    USE ${WORDPRESS_DB_NAME};
    SET FOREIGN_KEY_CHECKS = 0;
    DROP TABLE IF EXISTS wp_commentmeta, wp_comments, wp_links, wp_options, wp_postmeta, wp_posts, wp_term_relationships, wp_term_taxonomy, wp_termmeta, wp_terms, wp_usermeta, wp_users;
    SET FOREIGN_KEY_CHECKS = 1;
    " 2>/dev/null
    
    # Read admin credentials from environment variables
    ADMIN_USER=${WP_ADMIN_USER}
    ADMIN_EMAIL=${WP_ADMIN_EMAIL}
    ADMIN_PASSWORD=${WP_ADMIN_PASSWORD}
    REGULAR_USER=${WP_USER}
    REGULAR_EMAIL=${WP_USER_EMAIL}
    REGULAR_PASSWORD=${WP_USER_PASSWORD}
    SITE_URL=${WP_SITE_URL}
    
    # Create WordPress installation script
    cat > /tmp/install_wp.php << EOF
<?php
// Set up WordPress environment
define('WP_INSTALLING', true);
\$_SERVER['HTTP_HOST'] = '${DOMAIN_NAME}';
\$_SERVER['REQUEST_URI'] = '/';
\$_SERVER['HTTPS'] = 'on';

require_once('/var/www/html/wp-config.php');
require_once('/var/www/html/wp-admin/includes/upgrade.php');
require_once('/var/www/html/wp-includes/wp-db.php');

// Create database tables with compliant admin username
wp_install('Inception WordPress', '${ADMIN_USER}', '${ADMIN_EMAIL}', true, '', '${ADMIN_PASSWORD}');

// Set the site URL properly
update_option('siteurl', '${SITE_URL}');
update_option('home', '${SITE_URL}');

// Create a regular user for commenting
\$user_id = wp_create_user('${REGULAR_USER}', '${REGULAR_PASSWORD}', '${REGULAR_EMAIL}');
if (!is_wp_error(\$user_id)) {
    \$user = new WP_User(\$user_id);
    \$user->set_role('subscriber');
    echo "Regular user created successfully!\n";
}

// Enable comments on posts
update_option('default_comment_status', 'open');

echo "WordPress installed successfully!\n";
?>
EOF
    
    # Run the installation
    php /tmp/install_wp.php
    rm /tmp/install_wp.php
    
    echo "WordPress installation completed!"
else
    echo "WordPress is already installed ($TABLES_COUNT tables found)"
fi

echo "WordPress setup completed, starting PHP-FPM..."

# Start PHP-FPM
exec "$@"