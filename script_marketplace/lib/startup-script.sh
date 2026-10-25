#!/bin/bash
#
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Main startup script for GCP Marketplace VM deployments

set -e

readonly LOG_FILE="/var/log/startup-script.log"
readonly PRODUCT_NAME="$(cat /opt/c2d/product.name 2>/dev/null || echo "Application")"

exec 1> >(tee -a "${LOG_FILE}")
exec 2>&1

echo "=========================================="
echo "${PRODUCT_NAME} GCP Marketplace Startup Script"
echo "Started at: $(date)"
echo "=========================================="

mkdir -p /opt/c2d/scripts

echo "Running configuration scripts..."

for script in /opt/c2d/scripts/*.sh; do
  if [[ -f "${script}" ]]; then
    echo "Executing: ${script}"
    bash "${script}" || {
      echo "ERROR: Script ${script} failed"
      exit 1
    }
  fi
done

echo "=========================================="
echo "Startup script completed successfully"
echo "Completed at: $(date)"
echo "=========================================="
