# Image runbook

## Build and publish (normal path)

GitHub Actions on tag `v<DOCKER_TAG>` builds linux/amd64 and linux/arm64, runs the Scout gate on both, pushes Docker Hub, signs the index digest with Cosign (keyless), and attaches an SBOM to the GitHub Release.

1. Bump [`versions.lock`](../versions.lock) and the compose/docs mirrors.
2. `./scripts/verify-build-manifest.sh`
3. Commit on `moodle-core-5-3`, merge to `main` if this is the current line.
4. Tag `v<DOCKER_TAG>` with the plain-text shape in [RELEASE-NOTES-POLICY.md](RELEASE-NOTES-POLICY.md).
5. Push the branch, then the tag. Do not retag `latest`.

## Laptop break-glass

Use only when Actions cannot publish. Requires an approver.

```bash
./scripts/verify-build-manifest.sh
make push
# Record the index digest. Scout both platforms.
docker scout cves --only-severity critical --platform linux/amd64 registry://abstechnology/moodle-standard:$TAG
docker scout cves --only-severity critical --platform linux/arm64 registry://abstechnology/moodle-standard:$TAG
```

`PUSH_ON_FAIL=yes` is not a release path. It needs a written exception in [SECURITY-EXCEPTIONS.md](SECURITY-EXCEPTIONS.md).

`make tag-latest` is disabled unless `CONFIRM_RETAG_LATEST=yes`. Do not use it for a revision.

## Rollback

Published tags are immutable.

1. Point compose, Helm, or Terraform at the previous tag (`5.3.0-r4` if `5.3.0-r5` is bad).
2. Do not delete the bad Hub tag. Write the reason on the GitHub Release.
3. Ship a new `rN` with the fix.

## CVE incident

1. Confirm the package and the platform (`linux/amd64` and `linux/arm64`).
2. If Debian or PHP already has a fix, bump the pin in `versions.lock` and ship `rN`.
3. If there is no distro fix, upgrade the binary in the image and record the SBOM story in [SECURITY-EXCEPTIONS.md](SECURITY-EXCEPTIONS.md). Do not call Scout “clean” if a package record was dropped.
4. Live VMs stay on the image they were created with unless the customer asks to roll.

## Smoke

```bash
./scripts/smoke-image.sh abstechnology/moodle-standard:5.3.0-r5
```
