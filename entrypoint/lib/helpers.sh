#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

# Check if script is being sourced
_is_sourced() {
    # https://unix.stackexchange.com/a/215279
    [ "${#FUNCNAME[@]}" -ge 2 ] \
        && [ "${FUNCNAME[0]}" = '_is_sourced' ] \
        && [ "${FUNCNAME[1]}" = 'source' ]
}

# Wait for database to be ready
wait_for_db() {
    local host=$1
    local port=$2
    local user=$3
    local password=$4
    local max_attempts=${5:-30}
    local attempt=0
    local mysql_cmd
    
    log_info "Waiting for database connection at $host:$port..."
    
    # Construct MySQL command based on whether password is provided
    if [ -n "$password" ]; then
        mysql_cmd="mysql -h \"$host\" -P \"$port\" -u \"$user\" -p\"$password\" -e \"SELECT 1\""
    else
        log_warn "No database password provided, attempting connection without password"
        mysql_cmd="mysql -h \"$host\" -P \"$port\" -u \"$user\" -e \"SELECT 1\""
    fi
    
    while [ $attempt -lt $max_attempts ]; do
        if eval "$mysql_cmd" >/dev/null 2>&1; then
            log_info "Database connection established"
            return 0
        fi
        
        attempt=$((attempt+1))
        log_info "Waiting for database connection... Attempt $attempt/$max_attempts"
        sleep 2
    done
    
    log_error "Could not connect to database after $max_attempts attempts"
    return 1
}

# Generate random password
generate_random_password() {
    local length=${1:-16}
    LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()-_=+' </dev/urandom | head -c "$length"
}

# Check if a directory is empty
is_dir_empty() {
    local dir=$1
    [ -z "$(ls -A "$dir")" ]
}

# Check if a file exists and is readable
file_exists_and_readable() {
    local file=$1
    [ -f "$file" ] && [ -r "$file" ]
}

# Check if a directory exists and is writable
dir_exists_and_writable() {
    local dir=$1
    [ -d "$dir" ] && [ -w "$dir" ]
}

# Create directory with proper permissions if it doesn't exist
ensure_dir_exists() {
    local dir=$1
    local owner=${2:-}
    
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
    
    if [ -n "$owner" ]; then
        chown -R "$owner" "$dir"
        log_info "Set ownership of $dir to $owner"
    fi
}

# Check if a string contains a substring
string_contains() {
    local string=$1
    local substring=$2
    [[ "$string" == *"$substring"* ]]
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Execute a command with timeout
execute_with_timeout() {
    local timeout=$1
    local cmd=$2
    shift 2
    
    timeout "$timeout" "$cmd" "$@"
    return $?
} 