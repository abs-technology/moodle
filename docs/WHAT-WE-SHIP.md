# What we ship

## In this repository

| Artifact | What it is | What it is not |
|----------|------------|----------------|
| `abstechnology/moodle-standard:<tag>` | Moodle runtime: Apache, PHP, Moodle from packaging.moodle.org, entrypoint, health probes | A Moodle core fork. We do not vendor Moodle in git. |
| `versions.lock` | Pin for Moodle, PHP, MariaDB client, base digest, checksums | A live VM inventory |
| `docker-compose.yml` + `examples/` | Local and reference compose | A customer site |
| `terraform/modules/` + `terraform/templates/` | AWS/GCP VM modules | A customer's passwords, state, or break-glass key |
| `gke-moodle/` | Optional GKE + Helm stack | The VM marketplace path |
| GitHub Release `v<DOCKER_TAG>` | Notes, digest, SBOM asset | A replacement for the Hub image |

## Not in git

| Path | Why |
|------|-----|
| `script_marketplace/` | First-boot GCP Marketplace unit. Kept on the deploy machine. See [terraform/README.md](../terraform/README.md). |
| `terraform/deployments/*/*.tfvars` | Customer credentials and generated passwords |
| `*.pem`, `*.tfstate` | Secrets and live state |
| `.env` | Local compose secrets |

## Not this product

- Moodle plugins a customer installs after first boot
- The MariaDB **server** (compose and VMs use `mariadb:11.8.9`; the image only has the client)
- Official Moodle HQ security releases (we consume their tarball)
- Already-deployed VMs. A new image tag does not roll those hosts.

## Default checkout

Work from `main` or `moodle-core-5-3`. The published image is the Hub tag in `versions.lock` plus the matching GitHub Release. Do not treat an unpublished local branch as the product. Do not commit or open customer tfvars.
