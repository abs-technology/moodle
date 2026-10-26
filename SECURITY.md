# Security

Report a vulnerability in this image or the deploy scripts to **security@absi.edu.vn**.
Do not open a public GitHub issue for an unfixed flaw.

## Response

| Severity | First reply | Status update |
|----------|-------------|---------------|
| Critical (RCE, auth bypass, secret leak) | 2 business days | Every 2 business days until a tag or a written exception |
| High | 5 business days | Weekly |
| Medium / Low | 10 business days | On the next image revision |

We ship a new image revision (`5.3.0-rN`) rather than moving a published tag. `latest` is not retagged.

## What this repository is

`abstechnology/moodle-standard` is a Moodle runtime image plus optional AWS/GCP VM modules. Moodle core is downloaded at build time from [packaging.moodle.org](https://packaging.moodle.org). Core Moodle bugs belong with [Moodle HQ](https://moodle.org/security/).

## What to include

- Image tag and index digest (`docker buildx imagetools inspect`)
- Platform (`linux/amd64` or `linux/arm64`)
- Scout or other scanner output, if any
- Whether the host is compose, a VM from `terraform/`, or GKE

## Exceptions

Known scanner findings that we accept, and why, live in [docs/SECURITY-EXCEPTIONS.md](docs/SECURITY-EXCEPTIONS.md).
The release process is [docs/RELEASE-NOTES-POLICY.md](docs/RELEASE-NOTES-POLICY.md).
Rollback and incident steps are [docs/RUNBOOK.md](docs/RUNBOOK.md).
