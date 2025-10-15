#!/bin/sh

# Initialize MariaDB if not already done
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

# Start MariaDB in background with skip-grant-tables for initial setup
echo "Starting MariaDB for initial setup..."
mariadbd-safe --datadir=/var/lib/mysql --user=mysql --skip-grant-tables &

# Wait for MariaDB to start
echo "Waiting for MariaDB to start..."
while ! mariadb-admin ping --silent 2>/dev/null; do
    sleep 1
done

# Read passwords from secrets
DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

echo "Setting up database and users..."
# First flush privileges to enable user management, then create database and users
mariadb << EOF
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

echo "Database setup completed!"

# Stop the background MariaDB
mariadb-admin -u root -p"${DB_ROOT_PASSWORD}" shutdown

echo "Restarting MariaDB with normal authentication..."
# Start MariaDB in foreground with normal authentication
exec "$@"