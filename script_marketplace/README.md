# VM Marketplace scripts

First-boot scripts that apply Terraform metadata credentials on Marketplace deploy.

## Layout (same for every product)

```
script_vm_<product>/
├── lib/                        # Copy of script_vm/lib/ (synced per product by make setup-vm-scripts)
│   ├── c2d-utils               # GCP metadata helpers
│   ├── marketplace-admin.sh    # Shared credential flow
│   ├── startup-script.sh       # Runs /opt/c2d/scripts/*.sh
│   └── install-marketplace.sh  # Installs to /opt/c2d on VM
├── 01-configure-<product>.sh   # Product-specific apply logic only
└── install.sh                  # Thin wrapper (sets MP_* vars)
```

| Product | Directory | Metadata keys | Flag |
|---------|-----------|---------------|------|
| Moodle | `script_vm/` | `moodle-admin-password`, `moodle-admin-email` | `.moodle-metadata-applied` |
| Drupal | `script_vm_drupal/` | `drupal-admin-password`, `drupal-admin-email` | `.drupal-metadata-applied` |
| WordPress | `script_vm_wordpress/` | `wordpress-admin-password`, `wordpress-admin-email` | `.wordpress-metadata-applied` |
| Joomla | `script_vm_joomla/` | `joomla-admin-password`, `joomla-admin-email` | `.joomla-metadata-applied` |

## Shared flow (`marketplace-admin.sh`)

1. Read password + email from GCP metadata
2. Skip if no password (source VM) or flag already set (one-time apply)
3. Wait for Docker container(s) healthy (180s max)
4. Wait 10s for app ready
5. **Product script** applies credentials
6. Touch metadata + configured flags

## Install on source VM

```bash
make setup-vm-scripts VERSION=drupal-v11
```

## Edit shared library

Canonical source: `script_vm/lib/`.

- **`make setup-vm-scripts VERSION=...`** — copies lib only into that product's scripts dir before install.
- **`./scripts/sync-vm-lib.sh`** — optional; sync lib to all products at once (local dev only).
