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

# Shared first-boot admin credential flow for GCP Marketplace VMs.
# Source after /opt/c2d/c2d-utils.

readonly MP_DEFAULT_ADMIN_EMAIL="admin@example.com"
readonly MP_DEFAULT_MAX_WAIT=180
readonly MP_READY_SLEEP=10

mp_read_admin_metadata() {
  local password_key="$1"
  local email_key="$2"

  ADMIN_PASSWORD="$(get_attribute_value "${password_key}" 2>/dev/null || echo "")"
  ADMIN_EMAIL="$(get_attribute_value "${email_key}" 2>/dev/null || echo "")"
}

mp_handle_metadata_precheck() {
  local product_label="$1"
  local metadata_flag="$2"

  log "Checking for ${product_label} admin credentials in metadata..."

  if [[ -z "${ADMIN_PASSWORD}" ]]; then
    log "No admin password in metadata. Skipping."
    log "This is normal for source/development VMs."
    exit 0
  fi

  if [[ -f "${metadata_flag}" ]]; then
    log "Password from metadata was already applied on first boot."
    log "Skipping update to preserve any user password changes."
    exit 0
  fi

  log "Found credentials in metadata. This is first boot - updating admin account..."

  if [[ -z "${ADMIN_EMAIL}" ]]; then
    log "WARNING: No admin email in metadata. Using default."
    ADMIN_EMAIL="${MP_DEFAULT_ADMIN_EMAIL}"
  fi
}

wait_for_containers_healthy() {
  local max_wait="${1:-${MP_DEFAULT_MAX_WAIT}}"
  shift
  local containers=("$@")
  local elapsed=0
  local status_parts=()

  log "Waiting for containers to be healthy..."
  while [ "${elapsed}" -lt "${max_wait}" ]; do
    local all_healthy=true
    status_parts=()

    for container in "${containers[@]}"; do
      local health
      health="$(docker inspect --format='{{.State.Health.Status}}' "${container}" 2>/dev/null || echo "starting")"
      status_parts+=("${container}=${health}")
      if [[ "${health}" != "healthy" ]]; then
        all_healthy=false
      fi
    done

    if [[ "${all_healthy}" == "true" ]]; then
      log "Containers are healthy: $(IFS=', '; echo "${status_parts[*]}")"
      return 0
    fi

    log "Waiting... $(IFS=', '; echo "${status_parts[*]}") (${elapsed}s/${max_wait}s)"
    sleep 5
    elapsed=$((elapsed + 5))
  done

  log_error "Containers did not become healthy within ${max_wait}s: $(IFS=', '; echo "${status_parts[*]}")"
  return 1
}

mp_wait_for_application_ready() {
  local message="${1:-Waiting for application to be ready...}"
  log "${message}"
  sleep "${MP_READY_SLEEP}"
}

mp_mark_credentials_applied() {
  local metadata_flag="$1"
  local configured_flag="$2"

  touch "${metadata_flag}"
  touch "${configured_flag}"
}

mp_log_credentials_applied() {
  log_success "Initial admin credentials set from Terraform metadata!"
  log "Email: ${ADMIN_EMAIL}"
  log "Password: ******** (check Terraform output)"
  log ""
  log "Note: Future VM restarts will preserve any password changes you make."
}
