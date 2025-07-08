#!/bin/bash
# Copyright Absi Technology. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh

# Assume environment variables for database connection are set or can be sourced
# For simplicity, using hardcoded env vars as passed by docker-compose for this script.
MARIADB_HOST="${MOODLE_DATABASE_HOST:-mariadb}"
MARIADB_PORT_NUMBER="${MOODLE_DATABASE_PORT_NUMBER:-3306}"
MARIADB_USER="${MOODLE_DATABASE_USER:-absi_moodle_user}"
MARIADB_PASSWORD="${MOODLE_DATABASE_PASSWORD:-password}"
MARIADB_DATABASE="${MOODLE_DATABASE_NAME:-absi_moodle_db}" # Use Moodle's DB name

mysql_execute() {
    local -r sql_file="${1:?missing file}"
    local failure=0
    local mysql_cmd=("mysql" "-h" "$MARIADB_HOST" "-P" "$MARIADB_PORT_NUMBER" "-u" "$MARIADB_USER" "-D" "$MARIADB_DATABASE")

    # Only add password if it's not empty
    if [[ -n "$MARIADB_PASSWORD" ]]; then
        mysql_cmd+=("-p$MARIADB_PASSWORD")
    fi

    if [[ "$sql_file" == *".sql" ]]; then
        "${mysql_cmd[@]}" < "$sql_file" || failure=$?
    elif [[ "$sql_file" == *".sql.gz" ]]; then
        gunzip -c "$sql_file" | "${mysql_cmd[@]}" || failure=$?
    fi
    return "$failure"
}

read -r -a custom_init_scripts <<< "$@"
failure=0
if [[ "${#custom_init_scripts[@]}" -gt 0 ]]; then
    for custom_init_script in "${custom_init_scripts[@]}"; do
        [[ ! "$custom_init_script" =~ ^.*(\.sql|\.sql\.gz)$ ]] && continue
        info "Executing ${custom_init_script}"
        mysql_execute "$custom_init_script" || failure=1
        [[ "$failure" -ne 0 ]] && error "Failed to execute ${custom_init_script}"
    done
fi

exit "$failure"
