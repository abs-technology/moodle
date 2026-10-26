#!/bin/bash
# Verify versions.lock matches Dockerfile, Makefile, and docker-compose.yml.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/versions.lock"
errors=0

err() { printf 'ERROR: %s\n' "$1"; errors=$((errors + 1)); }

if [[ ! -f "$LOCK" ]]; then
    echo "FATAL: $LOCK not found" >&2
    exit 1
fi

while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue
    key="${line%% := *}"
    val="${line#* := }"
    key="${key// /}"
    export "$key=$val"
done < "$LOCK"

check_eq() {
    local label=$1 expected=$2 actual=$3
    [[ "$expected" == "$actual" ]] || err "$label: expected '$expected', got '$actual'"
}

df_moodle=$(grep -E '^ARG MOODLE_VERSION=' "$ROOT/Dockerfile" | head -1 | cut -d= -f2)
df_prefix=$(grep -E '^ARG MOODLE_RELEASE_PREFIX=' "$ROOT/Dockerfile" | head -1 | cut -d= -f2)
df_php=$(grep -E '^ARG PHP_VERSION=' "$ROOT/Dockerfile" | head -1 | cut -d= -f2)
df_php_release=$(grep -E '^ARG PHP_RELEASE=' "$ROOT/Dockerfile" | head -1 | cut -d= -f2)
df_url=$(grep -E '^ARG MOODLE_DOWNLOAD_URL=' "$ROOT/Dockerfile" | head -1 | cut -d= -f2-)

check_eq "Dockerfile MOODLE_VERSION" "$MOODLE_VERSION" "$df_moodle"
check_eq "Dockerfile MOODLE_RELEASE_PREFIX" "$MOODLE_RELEASE_PREFIX" "$df_prefix"
check_eq "Dockerfile PHP_VERSION" "$PHP_VERSION" "$df_php"
check_eq "Dockerfile PHP_RELEASE" "${PHP_RELEASE:-}" "$df_php_release"
check_eq "Dockerfile MOODLE_DOWNLOAD_URL" "$MOODLE_DOWNLOAD_URL" "$df_url"

mk_tag=$(grep -E '^TAG\s+\?=' "$ROOT/Makefile" | head -1 | awk '{print $3}')
if [[ "$mk_tag" != "$DOCKER_TAG" && "$mk_tag" != '$(DOCKER_TAG)' ]]; then
    err "Makefile TAG: expected '$DOCKER_TAG' or '\$(DOCKER_TAG)', got '$mk_tag'"
fi

compose_tag=$(grep -E 'image:.*moodle-standard:' "$ROOT/docker-compose.yml" | head -1 | sed 's/.*://')
check_eq "docker-compose tag" "$DOCKER_TAG" "$compose_tag"

df_from=$(grep -E '^ARG BASE_IMAGE=' "$ROOT/Dockerfile" | head -1 | cut -d= -f2-)
check_eq "Dockerfile BASE_IMAGE" "${BASE_IMAGE}@${BASE_IMAGE_DIGEST}" "$df_from"
df_mdb=$(grep -E '^ARG MARIADB_IMAGE=' "$ROOT/Dockerfile" | head -1 | cut -d= -f2-)
check_eq "Dockerfile MariaDB client" "${MARIADB_IMAGE}@${MARIADB_IMAGE_DIGEST}" "$df_mdb"

if ! grep -q "echo \"\${MOODLE_TGZ_SHA256}" "$ROOT/Dockerfile"; then
    err "Dockerfile Moodle tarball: expected a sha256 check"
fi
if ! grep -q "getcomposer.org/download/\${COMPOSER_VERSION}/composer.phar" "$ROOT/Dockerfile"; then
    err "Dockerfile Composer: expected a pinned composer.phar download"
fi
if grep -q 'getcomposer.org/installer | php' "$ROOT/Dockerfile"; then
    err "Dockerfile Composer: installer pipe is not allowed"
fi

df_sury=$(grep -E '^ARG SURY_PHP_GPG_SHA256=' "$ROOT/Dockerfile" | head -1 | cut -d= -f2)
check_eq "Dockerfile SURY_PHP_GPG_SHA256" "${SURY_PHP_GPG_SHA256:-}" "$df_sury"
df_composer_sha=$(grep -E '^ARG COMPOSER_SHA256=' "$ROOT/Dockerfile" | head -1 | cut -d= -f2)
check_eq "Dockerfile COMPOSER_SHA256" "${COMPOSER_SHA256:-}" "$df_composer_sha"
df_moodle_sha=$(grep -E '^ARG MOODLE_TGZ_SHA256=' "$ROOT/Dockerfile" | head -1 | cut -d= -f2)
check_eq "Dockerfile MOODLE_TGZ_SHA256" "${MOODLE_TGZ_SHA256:-}" "$df_moodle_sha"

if grep -qE 'public/admin/cli' "$ROOT/scripts/moodle-run.sh" "$ROOT/scripts/setup/moodle.sh" 2>/dev/null; then
    err "Scripts reference wrong CLI path public/admin/cli (Moodle 5.x uses admin/cli at root)"
fi

if (( errors == 0 )); then
    echo "OK: build manifest consistent (Moodle ${MOODLE_VERSION}, PHP ${PHP_RELEASE:-$PHP_VERSION}, tag ${DOCKER_TAG})"
    exit 0
fi

echo ""
echo "Found $errors inconsistency(ies)."
exit 1
