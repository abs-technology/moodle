#!/bin/bash
# Copyright Absi Technology. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

. /scripts/lib/logging.sh

debug "Loading filesystem.sh library"

ensure_dir_exists() {
    local dir="${1:?directory is missing}"
    local owner_user="${2:-}"
    local owner_group="${3:-}"
    local permissions="${4:-}"

    debug "Ensuring directory exists: $dir"
    debug "Owner user: $owner_user, Owner group: $owner_group, Permissions: $permissions"

    [ -d "${dir}" ] || mkdir -p "${dir}"
    debug "Directory creation/check completed with exit code: $?"

    if [[ -n "$owner_user" ]]; then
        if [[ -n "$owner_group" ]]; then
            debug "Setting ownership to $owner_user:$owner_group"
            chown "$owner_user":"$owner_group" "$dir"
        else
            debug "Setting ownership to $owner_user:$owner_user"
            chown "$owner_user":"$owner_user" "$dir"
        fi
        debug "Ownership set with exit code: $?"
    fi
    if [[ -n "$permissions" ]]; then
        debug "Setting permissions to $permissions"
        chmod "$permissions" "$dir"
        debug "Permissions set with exit code: $?"
    fi
}

is_dir_empty() {
    local -r path="${1:?missing directory}"
    debug "Checking if directory is empty: $path"
    if [[ ! -e "$path" ]] || [[ -z "$(ls -A "$path")" ]]; then
        debug "Directory is empty or does not exist"
        true
    else
        debug "Directory is not empty"
        false
    fi
}

run_as_user() {
    local userspec="$1"
    shift
    local cmd_with_args=("$@")
    debug "Running command as user $userspec: ${cmd_with_args[*]}"
    if [[ "$(id -u)" = "0" ]]; then
        su -s /bin/bash "$userspec" -c "$(printf "%q " "${cmd_with_args[@]}")"
        debug "Command execution completed with exit code: $?"
    else
        error "run_as_user must be executed as root."
        exit 1
    fi
}

user_exists() {
    local user="${1:?user is missing}"
    debug "Checking if user exists: $user"
    id "$user" >/dev/null 2>&1
    debug "User check completed with exit code: $?"
}

group_exists() {
    local group="${1:?group is missing}"
    debug "Checking if group exists: $group"
    getent group "$group" >/dev/null 2>&1
    debug "Group check completed with exit code: $?"
}

ensure_group_exists() {
    local group="${1:?group is missing}"
    debug "Ensuring group exists: $group"
    if ! group_exists "$group"; then
        debug "Group does not exist, creating..."
        groupadd "$group" >/dev/null 2>&1
        debug "Group creation completed with exit code: $?"
    else
        debug "Group already exists"
    fi
}

ensure_user_exists() {
    local user="${1:?user is missing}"
    local group="${2:-}"
    debug "Ensuring user exists: $user"
    debug "Group: $group"

    if ! user_exists "$user"; then
        debug "User does not exist, creating..."
        local -a user_args=("-r" "$user")
        if [[ -n "$group" ]]; then
            ensure_group_exists "$group"
            user_args+=("-g" "$group")
        fi
        useradd "${user_args[@]}" >/dev/null 2>&1
        debug "User creation completed with exit code: $?"
    else
        debug "User already exists"
    fi

    if [[ -n "$group" ]]; then
        debug "Setting user's primary group to $group"
        usermod -g "$group" "$user" >/dev/null 2>&1
        debug "Group modification completed with exit code: $?"
    fi
}

debug "Filesystem.sh library loaded"
