#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh
. /scripts/lib/config.sh
. /scripts/lib/mariadb.sh

# Load centralized configuration
load_config

info "Starting MariaDB Client setup for Absi Technology..."

# 1. Wait for MariaDB to be ready
check_db_server_connection() {
    echo "SELECT 1" | mariadb_remote_execute \
        "$MARIADB_HOST" \
        "$MARIADB_PORT_NUMBER" \
        "$MARIADB_DATABASE" \
        "root" \
        "$MARIADB_ROOT_PASSWORD"
}

info "Waiting for database server to be ready..."
if ! retry_while "check_db_server_connection" 60 5; then
    error "Database server did not become ready!"
    exit 1
fi
info "Database server is ready."

# Check and configure server character set
info "Checking MariaDB server character set configuration..."
server_charset=$(echo "SHOW VARIABLES LIKE 'character_set_server';" | mariadb_remote_execute \
    "$MARIADB_HOST" \
    "$MARIADB_PORT_NUMBER" \
    "" \
    "root" \
    "$MARIADB_ROOT_PASSWORD" | cut -f2)

info "Server character set: $server_charset"

if [[ "$server_charset" != "utf8mb4" ]]; then
    warn "Server character set is not utf8mb4. Setting session defaults..."
    mariadb_remote_execute "$MARIADB_HOST" "$MARIADB_PORT_NUMBER" "" "root" "$MARIADB_ROOT_PASSWORD" <<EOF_SQL
SET GLOBAL character_set_server = 'utf8mb4';
SET GLOBAL collation_server = 'utf8mb4_unicode_ci';
SET GLOBAL character_set_database = 'utf8mb4';
SET GLOBAL collation_database = 'utf8mb4_unicode_ci';
EOF_SQL
    info "Server character set updated to utf8mb4"
fi

# 2. Ensure database exists
mariadb_ensure_database_exists "$MARIADB_DATABASE" \
    --character-set "$MARIADB_CHARACTER_SET" \
    --collate "$MARIADB_COLLATE" \
    --host "$MARIADB_HOST" \
    --port "$MARIADB_PORT_NUMBER" \
    -u "root" -p "$MARIADB_ROOT_PASSWORD"

# 3. Ensure user exists
mariadb_ensure_user_exists "$MARIADB_USER" \
    -p "$MARIADB_PASSWORD" \
    --host "$MARIADB_HOST" \
    --port "$MARIADB_PORT_NUMBER" \
    --root-user "root" --root-password "$MARIADB_ROOT_PASSWORD"

# 4. Grant privileges
mariadb_ensure_user_has_database_privileges "$MARIADB_USER" "$MARIADB_DATABASE" "ALL" \
    --host "$MARIADB_HOST" \
    --port "$MARIADB_PORT_NUMBER" \
    --root-user "root" --root-password "$MARIADB_ROOT_PASSWORD"

# 5. Verify application user connection
check_user_connection() {
    echo "SELECT 1" | mariadb_remote_execute \
        "$MARIADB_HOST" \
        "$MARIADB_PORT_NUMBER" \
        "$MARIADB_DATABASE" \
        "$MARIADB_USER" \
        "$MARIADB_PASSWORD"
}

info "Verifying application user connection..."
if ! retry_while "check_user_connection" 10 2; then
    error "Failed to connect with user $MARIADB_USER!"
    exit 1
fi
info "User connection verified."

info "MariaDB client setup finished."

