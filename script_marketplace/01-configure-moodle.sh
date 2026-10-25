#!/bin/bash -eu
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

# Update Moodle admin credentials from GCP metadata

source /opt/c2d/c2d-utils || exit 1
source /opt/c2d/lib/marketplace-admin.sh || exit 1

readonly PRODUCT_LABEL="Moodle"
readonly METADATA_PASSWORD_KEY="moodle-admin-password"
readonly METADATA_EMAIL_KEY="moodle-admin-email"
readonly METADATA_APPLIED_FLAG="/opt/c2d/.moodle-metadata-applied"
readonly CONFIGURED_FLAG="/opt/c2d/.moodle-configured"
readonly MOODLE_CONTAINER="abs-moodle"
readonly DB_CONTAINER="abs-mariadb"
readonly ADMIN_USERNAME="admin"

mp_read_admin_metadata "${METADATA_PASSWORD_KEY}" "${METADATA_EMAIL_KEY}"
mp_handle_metadata_precheck "${PRODUCT_LABEL}" "${METADATA_APPLIED_FLAG}"

wait_for_containers_healthy "${MP_DEFAULT_MAX_WAIT}" "${MOODLE_CONTAINER}" "${DB_CONTAINER}" || exit 1
mp_wait_for_application_ready "Waiting for database to be fully ready..."

DB_NAME=$(docker exec "${MOODLE_CONTAINER}" bash -c 'echo $MOODLE_DATABASE_NAME')
DB_USER=$(docker exec "${MOODLE_CONTAINER}" bash -c 'echo $MOODLE_DATABASE_USER')
DB_PASS=$(docker exec "${MOODLE_CONTAINER}" bash -c 'echo $MOODLE_DATABASE_PASSWORD')

log "Database: ${DB_NAME}, User: ${DB_USER}"

log "Generating password hash..."
PASSWORD_HASH=$(docker exec "${MOODLE_CONTAINER}" \
  php -r "echo crypt('${ADMIN_PASSWORD}', '\$6\$rounds=10000\$' . substr(md5(mt_rand()), 0, 16) . '\$');")

log "Updating admin credentials in database..."
UPDATE_RESULT=$(docker exec "${DB_CONTAINER}" mariadb -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" \
  -e "UPDATE mdl_user SET password='${PASSWORD_HASH}', email='${ADMIN_EMAIL}' WHERE username='${ADMIN_USERNAME}'; SELECT ROW_COUNT() as rows_affected;")

if echo "${UPDATE_RESULT}" | grep -q "1"; then
  log "Database update successful (1 row affected)"
else
  log_error "Database update may have failed. Result: ${UPDATE_RESULT}"
  exit 1
fi

mp_mark_credentials_applied "${METADATA_APPLIED_FLAG}" "${CONFIGURED_FLAG}"
mp_log_credentials_applied
