# Contributing

This repository ships `abstechnology/moodle-standard`. Read [docs/WHAT-WE-SHIP.md](docs/WHAT-WE-SHIP.md) before sending a change.

## Branches

| Branch | Role |
|--------|------|
| `main` | Current product line (Moodle 5.3). Review and merge target. |
| `moodle-core-5-3` | 5.3 development line. Same pin as `main` after promotion. |
| `moodle-core-5-2-3` | Maintenance for Moodle 5.2.3 |
| `moodle-core-4-5-*` | Maintenance for Moodle 4.5 |
| `moodle-core-4-3-12` | Maintenance for Moodle 4.3.12 |

Do not open a pull request from a dirty local line that is not pushed (`moodle-core-4-5-15` is not a product branch).

## Image change

1. Edit [`versions.lock`](versions.lock). That file is the pin.
2. Run `./scripts/verify-build-manifest.sh`.
3. One commit. Subject is one imperative sentence with a period. No `feat:` / `fix:` prefix. No AI attribution trailers. See [docs/RELEASE-NOTES-POLICY.md](docs/RELEASE-NOTES-POLICY.md) and [docs/NO-AGENT-ATTRIBUTION.md](docs/NO-AGENT-ATTRIBUTION.md).
4. Image publish is GitHub Actions on tag `v<DOCKER_TAG>`. Laptop `make push` is the break-glass path only.
5. Do not retag `latest`. Do not move a published tag. The next image is `rN`.

## Secrets

- Never commit `.env`, `*.tfvars`, `*.pem`, or Terraform state.
- `script_marketplace/` stays on the deploy machine. Do not add it back to git.
- Customer directories under `terraform/deployments/` are not the product. This repo tracks `terraform/modules/` and `terraform/templates/`.

## Local checks

```bash
./scripts/git-hooks/install.sh
./scripts/verify-build-manifest.sh
make build          # native arch, Scout gate
./scripts/smoke-image.sh abstechnology/moodle-standard:$(grep DOCKER_TAG versions.lock | awk '{print $3}')
```
