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

# Shared installer for Marketplace VM scripts.
# Required env: MP_PRODUCT_NAME, MP_CONFIGURE_SCRIPT, MP_SYSTEMD_SERVICE

set -euo pipefail

: "${MP_PRODUCT_NAME:?MP_PRODUCT_NAME is required}"
: "${MP_CONFIGURE_SCRIPT:?MP_CONFIGURE_SCRIPT is required}"
: "${MP_SYSTEMD_SERVICE:?MP_SYSTEMD_SERVICE is required}"

: "${MP_INSTALL_ROOT:?MP_INSTALL_ROOT is required}"

INSTALL_ROOT="${MP_INSTALL_ROOT}"

echo "Installing ${MP_PRODUCT_NAME} GCP Marketplace startup scripts..."

mkdir -p /opt/c2d/scripts /opt/c2d/lib

install -m 755 "${INSTALL_ROOT}/lib/c2d-utils" /opt/c2d/c2d-utils
install -m 755 "${INSTALL_ROOT}/lib/marketplace-admin.sh" /opt/c2d/lib/marketplace-admin.sh
install -m 755 "${INSTALL_ROOT}/lib/startup-script.sh" /opt/c2d/startup-script.sh
install -m 755 "${INSTALL_ROOT}/${MP_CONFIGURE_SCRIPT}" "/opt/c2d/scripts/${MP_CONFIGURE_SCRIPT}"
echo "${MP_PRODUCT_NAME}" > /opt/c2d/product.name

cat > "/etc/systemd/system/${MP_SYSTEMD_SERVICE}" <<EOF
[Unit]
Description=Google Marketplace ${MP_PRODUCT_NAME} Configuration
After=network-online.target docker.service
Wants=network-online.target
Before=sshd.service

[Service]
Type=oneshot
ExecStart=/opt/c2d/startup-script.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "${MP_SYSTEMD_SERVICE}"

echo "Created, enabled, and started systemd service: ${MP_SYSTEMD_SERVICE}"
echo ""
echo "=========================================="
echo "Installation complete!"
echo "=========================================="
echo ""
echo "Files installed:"
echo "  - /opt/c2d/c2d-utils"
echo "  - /opt/c2d/lib/marketplace-admin.sh"
echo "  - /opt/c2d/scripts/${MP_CONFIGURE_SCRIPT}"
echo "  - /opt/c2d/startup-script.sh"
echo "  - /etc/systemd/system/${MP_SYSTEMD_SERVICE}"
echo ""
echo "Manual run: sudo /opt/c2d/startup-script.sh"
echo ""
