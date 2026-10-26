#!/bin/bash
# Smoke the published (or just-built) Moodle image. No database required.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/versions.lock"
IMAGE="${1:-}"

while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue
    key="${line%% := *}"
    val="${line#* := }"
    key="${key// /}"
    export "$key=$val"
done < "$LOCK"

IMAGE="${IMAGE:-abstechnology/moodle-standard:${DOCKER_TAG}}"

docker run --rm --user root --entrypoint bash "$IMAGE" -c "
set -euo pipefail
test \"\$(php -r 'echo PHP_VERSION;')\" = '${PHP_RELEASE}'
grep -q 'session.upload_progress.enabled = 0' /etc/php/${PHP_VERSION}/apache2/php.ini
/usr/sbin/apache2 -v
mariadb --version | grep -q 'from ${MARIADB_CLIENT}-MariaDB'
test -e /usr/lib/apache2/modules/libphp${PHP_VERSION}.so
test -e /usr/local/share/ca-certificates/moodle-localhost.crt
# App user must not own the CA store or the private-key directory.
stat -c '%U %G' /etc/ssl/private | grep -q '^root '
stat -c '%a' /etc/ssl/private | grep -q '750'
test ! -e /var/lib/dpkg/status || ! grep -q '^Package: mariadb' /var/lib/dpkg/status
echo OK: ${DOCKER_TAG} PHP ${PHP_RELEASE} MariaDB ${MARIADB_CLIENT}
"
