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
df_url=$(grep -E '^ARG MOODLE_DOWNLOAD_URL=' "$ROOT/Dockerfile" | head -1 | cut -d= -f2-)

check_eq "Dockerfile MOODLE_VERSION" "$MOODLE_VERSION" "$df_moodle"
check_eq "Dockerfile MOODLE_RELEASE_PREFIX" "$MOODLE_RELEASE_PREFIX" "$df_prefix"
check_eq "Dockerfile PHP_VERSION" "$PHP_VERSION" "$df_php"
check_eq "Dockerfile MOODLE_DOWNLOAD_URL" "$MOODLE_DOWNLOAD_URL" "$df_url"

mk_tag=$(grep -E '^TAG\s+\?=' "$ROOT/Makefile" | head -1 | awk '{print $3}')
if [[ "$mk_tag" != "$DOCKER_TAG" && "$mk_tag" != '$(DOCKER_TAG)' ]]; then
    err "Makefile TAG: expected '$DOCKER_TAG' or '\$(DOCKER_TAG)', got '$mk_tag'"
fi

compose_tag=$(grep -E 'image:.*moodle-standard:' "$ROOT/docker-compose.yml" | head -1 | sed 's/.*://')
check_eq "docker-compose tag" "$DOCKER_TAG" "$compose_tag"

if grep -qE 'public/admin/cli' "$ROOT/scripts/moodle-run.sh" "$ROOT/scripts/setup/moodle.sh" 2>/dev/null; then
    err "Scripts reference wrong CLI path public/admin/cli (Moodle 5.2 uses admin/cli at root)"
fi

if (( errors == 0 )); then
    echo "OK: build manifest consistent (Moodle ${MOODLE_VERSION}, PHP ${PHP_VERSION}, tag ${DOCKER_TAG})"
    exit 0
fi

echo ""
echo "Found $errors inconsistency(ies)."
exit 1
