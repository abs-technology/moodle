#!/bin/bash
# Copyright Absi Technology. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

. /scripts/lib/logging.sh

retry_while() {
    local cmd="${1:?cmd is missing}"
    local retries="${2:-12}"
    local sleep_time="${3:-5}"
    local return_value=1

    read -r -a command <<<"$cmd"
    for ((i = 1; i <= retries; i += 1)); do
        if "${command[@]}"; then
            return_value=0
            break
        else
            debug "Retrying... (attempt $i/$retries)"
            sleep "$sleep_time"
        fi
    done
    return "$return_value"
}

is_boolean_yes() {
    local -r bool="${1:-}"
    shopt -s nocasematch
    if [[ "$bool" = 1 || "$bool" =~ ^(yes|true)$ ]]; then
        true
    else
        false
    fi
}
