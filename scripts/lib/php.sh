#!/bin/bash
# Copyright Absi Technology. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

. /scripts/lib/logging.sh

php_conf_set() {
    local -r key="${1:?key missing}"
    local -r value="${2:?value missing}"
    local -r file="${3:?file missing}"
    local pattern="^[; ]*${key}\s*=.*$"
    local entry="${key} = ${value}"

    if grep -q -E "$pattern" "$file"; then
        sed -i -E "s|${pattern}|${entry}|" "$file"
    else
        echo "$entry" >> "$file"
    fi
}

php_execute_print_output() {
    local php_cmd
    php_cmd="$(</dev/stdin)"
    debug "Executing PHP code:\n${php_cmd}"
    # Use 'php -r' for raw code execution or 'php -f -' to read from stdin
    # 'php -f -' is generally safer for complex scripts that might include <?php tags
    php -f - <<< "$php_cmd"
}
