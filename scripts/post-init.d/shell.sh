#!/bin/bash
# Copyright Absi Technology. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh

# Loop through all input files passed via stdin
read -r -a custom_init_scripts <<< "$@"
failure=0
if [[ "${#custom_init_scripts[@]}" -gt 0 ]]; then
    for custom_init_script in "${custom_init_scripts[@]}"; do
        [[ "$custom_init_script" != *".sh" ]] && continue
        if [[ -x "$custom_init_script" ]]; then
            info "Executing ${custom_init_script}"
            "$custom_init_script" || failure="1"
        else
            info "Sourcing ${custom_init_script} as it is not executable by the current user, any error may cause initialization to fail"
            . "$custom_init_script"
        fi
        [[ "$failure" -ne 0 ]] && error "Failed to execute ${custom_init_script}"
    done
fi

exit "$failure"
