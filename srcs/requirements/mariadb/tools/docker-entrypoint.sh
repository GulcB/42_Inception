#!/bin/sh
set -eu

if [ "${1:-}" != "mariadbd" ]; then
    exec "$@"
fi

: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"

case "$MYSQL_DATABASE" in
    *[!a-zA-Z0-9_]*)
        echo "Invalid MYSQL_DATABASE" >&2
        exit 1
        ;;
esac

case "$MYSQL_USER" in
    *[!a-zA-Z0-9_]*)
        echo "Invalid MYSQL_USER" >&2
        exit 1
        ;;
esac

if [ "$MYSQL_USER" = "root" ]; then
    echo "MYSQL_USER cannot be root" >&2
    exit 1
fi

for secret in db_password db_root_password; do
    if [ ! -r "/run/secrets/$secret" ]; then
        echo "Missing or unreadable secret: $secret" >&2
        exit 1
    fi
done

db_password="$(cat /run/secrets/db_password)"
root_password="$(cat /run/secrets/db_root_password)"

for password in "$db_password" "$root_password"; do
    case "$password" in
        *[!0-9a-f]*|"")
            echo "Passwords must contain only lowercase hexadecimal characters" >&2
            exit 1
            ;;
    esac

    if [ "${#password}" -ne 64 ]; then
        echo "Passwords must be 64 hexadecimal characters" >&2
        exit 1
    fi
done

if [ "$db_password" = "$root_password" ]; then
    echo "Database passwords must be different" >&2
    exit 1
fi

install -d -o mysql -g mysql -m 0750 /var/lib/mysql
install -d -o mysql -g mysql -m 0755 /run/mysqld

marker="/var/lib/mysql/.inception_initialized"

if [ ! -f "$marker" ]; then
    if [ -d /var/lib/mysql/mysql ]; then
        echo "Incomplete database initialization detected" >&2
        exit 1
    fi

    echo "Initializing MariaDB data directory..."

    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql \
        --auth-root-authentication-method=normal \
        --skip-test-db

    mariadbd --user=mysql --skip-networking --console &
    bootstrap_pid=$!

    cleanup() {
        kill -TERM "$bootstrap_pid" 2>/dev/null || true
        wait "$bootstrap_pid" 2>/dev/null || true
    }

    trap cleanup EXIT
    trap 'exit 1' HUP INT TERM

    ready=0

    for attempt in $(seq 1 30); do
        if mariadb --protocol=socket -u root \
            -N -s -e "SELECT 1" >/dev/null 2>&1; then
            ready=1
            break
        fi

        if ! kill -0 "$bootstrap_pid" 2>/dev/null; then
            echo "MariaDB exited during initialization" >&2
            exit 1
        fi

        sleep 1
    done

    if [ "$ready" -ne 1 ]; then
        echo "MariaDB initialization timed out" >&2
        exit 1
    fi

    mariadb --protocol=socket -u root <<SQL
ALTER USER 'root'@'localhost'
    IDENTIFIED BY '${root_password}';

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%'
    IDENTIFIED BY '${db_password}';

GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.*
    TO '${MYSQL_USER}'@'%';

FLUSH PRIVILEGES;
SQL

    kill -TERM "$bootstrap_pid"
    wait "$bootstrap_pid"

    trap - EXIT HUP INT TERM

    touch "$marker"
    chown mysql:mysql "$marker"

    echo "MariaDB initialization completed."
fi

unset db_password root_password

exec "$@"