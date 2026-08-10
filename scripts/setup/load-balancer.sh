#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# Shared session dir for multi-replica / load-balanced Moodle deployments.
# (Reverseproxy/sslproxy flags live in config.php — this script is not a proxy.)
. /scripts/lib/logging.sh
. /scripts/lib/config.sh
. /scripts/lib/validations.sh

load_config

info "Ensuring shared sessions directory..."

SESSIONS_DIR="${MOODLE_DATA_DIR}/sessions"
mkdir -p "$SESSIONS_DIR"
chown "$APP_USER:$APP_GROUP" "$SESSIONS_DIR" 2>/dev/null || true
chmod 755 "$SESSIONS_DIR" 2>/dev/null || true

# Full-tree chown/chmod on moodledata was removed: after H5P bootstrap the tree
# is huge and cost ~10–15s on bind mounts, while entrypoint already applies ACL
# / group perms earlier. Targeted fix only when explicitly requested.
if is_boolean_yes "${MOODLE_FIX_DATA_PERMS:-no}"; then
    info "MOODLE_FIX_DATA_PERMS=yes — recursive chown/chmod on $MOODLE_DATA_DIR"
    chown -R "$APP_USER:$APP_GROUP" "$MOODLE_DATA_DIR"
    find "$MOODLE_DATA_DIR" -type d -exec chmod 755 {} +
    find "$MOODLE_DATA_DIR" -type f -exec chmod 644 {} +
fi

info "Session directory ready"
