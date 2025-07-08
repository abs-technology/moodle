#!/bin/bash
# Copyright Absi Technology. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

. /scripts/lib/logging.sh
. /scripts/lib/validations.sh

cron_start() {
    if [[ -x "/usr/sbin/cron" ]]; then
        /usr/sbin/cron
    elif [[ -x "/usr/sbin/crond" ]]; then
        /usr/sbin/crond
    else
        false
    fi
}

generate_cron_conf() {
    local service_name="${1:?service name is missing}"
    local cmd="${2:?command is missing}"
    local run_as="root"
    local schedule="* * * * *"
    local clean="true"

    shift 2
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --run-as) shift; run_as="$1";;
            --schedule) shift; schedule="$1";;
            --no-clean) clean="false";;
            *) echo "Invalid command line flag ${1}" >&2; return 1;;
        esac
        shift
    done

    mkdir -p /etc/cron.d
    if "$clean"; then
        cat > "/etc/cron.d/${service_name}" <<CRON_EOF
# Cron job for Absi Technology Moodle service
${schedule} ${run_as} ${cmd}
CRON_EOF
    else
        echo "${schedule} ${run_as} ${cmd}" >> /etc/cron.d/"$service_name"
    fi
}
