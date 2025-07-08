#!/bin/bash
# Copyright Absi Technology. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

. /scripts/lib/logging.sh
. /scripts/lib/validations.sh

mariadb_remote_execute() {
    local -r hostname="${1:?hostname is required}"
    local -r port="${2:?port is required}"
    local -r db="${3:-}"
    local -r user="${4:-root}"
    local -r pass="${5:-}"
    local -a extra_opts=("${@:6}")

    local -a args=("-h" "$hostname" "-P" "$port" "--connect-timeout=5")
    args+=("-N" "-u" "$user")
    [[ -n "$pass" ]] && args+=("-p$pass") # Pass only if not empty
    [[ -n "$db" ]] && args+=("$db") # DB name only if not empty
    [[ "${#extra_opts[@]}" -gt 0 ]] && args+=("${extra_opts[@]}")

    local mysql_cmd
    mysql_cmd="$(</dev/stdin)"
    debug "Executing SQL command on ${hostname}:${port}:\n$mysql_cmd"
    mysql "${args[@]}" <<<"$mysql_cmd"
}

mariadb_ensure_database_exists() {
    local -r database="${1:?database is required}"
    local character_set=""
    local collate=""
    local db_host=""
    local db_port=""
    local user="root"
    local password=""

    shift 1
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --character-set) shift; character_set="$1";;
            --collate) shift; collate="$1";;
            --host) shift; db_host="$1";;
            --port) shift; db_port="$1";;
            -u|--user) shift; user="$1";;
            -p|--password) shift; password="$1";;
            *) error "Invalid flag $1"; return 1;;
        esac
        shift
    done

    local -a create_database_args=()
    [[ -n "$character_set" ]] && create_database_args+=("CHARACTER SET = '${character_set}'")
    [[ -n "$collate" ]] && create_database_args+=("COLLATE = '${collate}'")

    info "Creating database \`$database\` if not exists..."
    mariadb_remote_execute "$db_host" "$db_port" "mysql" "$user" "$password" <<EOF_SQL
    CREATE DATABASE IF NOT EXISTS \`$database\` ${create_database_args[@]:-};
EOF_SQL
}

mariadb_ensure_user_exists() {
    local -r user="${1:?user is required}"
    local password=""
    local db_host=""
    local db_port=""
    local root_user="root"
    local root_password=""

    shift 1
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -p|--password) shift; password="$1";;
            --host) shift; db_host="$1";;
            --port) shift; db_port="$1";;
            --root-user) shift; root_user="$1";;
            --root-password) shift; root_password="$1";;
            *) error "Invalid flag $1"; return 1;;
        esac
        shift
    done

    local auth_string=""
    [[ -n "$password" ]] && auth_string="IDENTIFIED BY '$password'"

    info "Creating user '$user'@'%' if not exists..."
    mariadb_remote_execute "$db_host" "$db_port" "mysql" "$root_user" "$root_password" <<EOF_SQL
    CREATE USER IF NOT EXISTS '$user'@'%' ${auth_string};
    FLUSH PRIVILEGES;
EOF_SQL
}

mariadb_ensure_user_has_database_privileges() {
    local -r user="${1:?user is required}"
    local -r database="${2:?db is required}"
    local -r privileges="${3:-ALL}"
    local db_host=""
    local db_port=""
    local root_user="root"
    local root_password=""

    shift 3
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --host) shift; db_host="$1";;
            --port) shift; db_port="$1";;
            --root-user) shift; root_user="$1";;
            --root-password) shift; root_password="$1";;
            *) error "Invalid flag $1"; return 1;;
        esac
        shift
    done

    info "Granting ${privileges} privileges on \`$database\`.* to '$user'@'%'..."
    mariadb_remote_execute "$db_host" "$db_port" "mysql" "$root_user" "$root_password" <<EOF_SQL
    GRANT ${privileges} ON \`$database\`.* TO '$user'@'%';
    FLUSH PRIVILEGES;
EOF_SQL
}
