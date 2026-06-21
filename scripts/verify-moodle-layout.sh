#!/bin/bash
# Verify Moodle 5.2 layout inside /opt/moodle-source (run at Docker build time).
set -euo pipefail

ROOT="${1:-/opt/moodle-source}"
PREFIX="${MOODLE_RELEASE_PREFIX:?MOODLE_RELEASE_PREFIX required}"

require_file() {
    local f="$1"
    if [[ ! -f "$ROOT/$f" ]]; then
        echo "FATAL: missing required file: $ROOT/$f" >&2
        exit 1
    fi
}

forbid_file() {
    local f="$1"
    if [[ -f "$ROOT/$f" ]]; then
        echo "FATAL: unexpected file (wrong layout): $ROOT/$f" >&2
        exit 1
    fi
}

# Parse $var from version.php without bootstrapping Moodle.
# version.php calls defined('MOODLE_INTERNAL') || die() — plain `php -r require` exits empty.
_parse_version_php_var() {
    local file=$1
    local var=$2
    sed -nE "/^[[:space:]]*\\\$${var}[[:space:]]*=/{
        s/^[^=]*=[[:space:]]*//
        s/[[:space:]]*;.*$//
        s/^[[:space:]]+//
        s/[[:space:]]+$//
        s/^['\"]+//
        s/['\"]+$//
        p
        q
    }" "$file"
}

require_file "public/version.php"
require_file "admin/cli/cron.php"
require_file "admin/cli/scheduled_task.php"
require_file "admin/cli/install_database.php"
require_file "admin/cli/upgrade.php"
require_file "config-dist.php"

# CLI must live at moodle root — NOT under public/ (verified against stable502 tarball).
forbid_file "public/admin/cli/cron.php"

VERSION_FILE="$ROOT/public/version.php"
RELEASE=$(_parse_version_php_var "$VERSION_FILE" "release")
VERSION=$(_parse_version_php_var "$VERSION_FILE" "version")

if [[ -z "$RELEASE" || -z "$VERSION" ]]; then
    echo "FATAL: could not parse release/version from $VERSION_FILE" >&2
    exit 1
fi

echo "Moodle release=${RELEASE} version=${VERSION}"

case "$RELEASE" in
    ${PREFIX}*) echo "Release prefix OK (${PREFIX})" ;;
    *) echo "FATAL: release '${RELEASE}' does not match prefix '${PREFIX}'" >&2; exit 1 ;;
esac

printf '%s\n%s\n%s\n%s\n' \
    "${MOODLE_VERSION:?}" "${PREFIX}" "${RELEASE}" "${VERSION}" \
    > "$ROOT/.absi-build-metadata"

echo "Layout verification passed."
