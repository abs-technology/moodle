# Security exceptions — Docker Scout

Image: `abstechnology/moodle-standard`  
Line: Moodle **5.3.0** on `debian:13-slim` (`BASE_IMAGE_DIGEST` in [`versions.lock`](../versions.lock)).

## How to read Scout

| Signal | Meaning |
|--------|---------|
| Quickview raw Critical | Every critical, including those Debian has not fixed |
| Policy **No fixable critical or high** | Release gate. Must PASS |
| Policy **Copyleft** | Expected on Debian/Apache/PHP. Ignored by the gate |
| Policy **Supply chain attestations** | Required when `ATTESTATIONS=full`. Skipped when `ATTESTATIONS=none` |

Release rule: the gate is **fixable** C/H. Raw criticals are reviewed here, not hidden.

Gate policy IDs (copyleft omitted on purpose):

- `default-non-root-user`
- `fixable-vulnerabilities`
- `high-profile-vulnerabilities`
- `no-stale-base-images`
- `approved-base-images`
- `supply-chain-attestations` (only if attestations are attached)

## MariaDB client (CVE-2026-92262, CVE-2026-85746)

Debian 13 still ships MariaDB **11.8.6**. Upstream fixed both CVEs in **11.8.9**. Debian's tracker has no fixed trixie version, so Scout marks every `pkg:deb/debian/mariadb` package vulnerable, including a rebuilt `1:11.8.9+maria~deb13`.

This image does **not** apt-install Debian's mariadb. It copies `mariadb` and `mariadb-dump` from `mariadb:11.8.9` (digest in `versions.lock`). Those two CVEs are server bugs. The binaries are the 11.8.9 client. They are not registered as a Debian package, so Scout does not attribute `debian/mariadb` to the image.

That is an SBOM choice, not a version lie. The client version is asserted at build (`from 11.8.9-MariaDB`).

## Bookworm lines (5.2.3, 4.5, 4.3.12) — Apache and libtiff

Debian 12 has no fixed `apache2` (2.4.68) or `tiff` (4.5.0) package. Scout's affected range on bookworm is `>0`. Relabeling the package version does not clear the finding.

Those lines compile Apache **2.4.69** and libtiff **4.7.2**, copy the binaries over the distro files, then drop the bookworm `apache2*` / `libtiff6` records from `/var/lib/dpkg/status` so Scout is not shown a bookworm package that Debian will never mark fixed.

Say this in a review: the **binaries** are the upstream fixes; the **distro packages** are absent from the SBOM because Bookworm has no fixed package. Do not say “Scout 0C because we patched Debian.”

5.3 on Debian 13 does not use that overlay. Trixie already has Apache 2.4.69 and a current libtiff.

## PHP

- 5.3 / 5.2: PHP **8.4.27** (CVE-2026-109618, CVE-2026-109619).
- 4.3.12: PHP **8.2.35** (same two CVEs). Moodle 4.3 does not run 8.3 or 8.4.
- `session.upload_progress.enabled=0` until PHP ships CVE-2026-115560.

## Attestations and Marketplace Go CVEs

Google Marketplace Artifact Analysis flags Go/containerd versions that live in BuildKit **attestation** manifests (`platform: unknown/unknown`), not in the Moodle runtime.

Default **`ATTESTATIONS=none`**: Hub image has no attached SBOM/provenance, so Marketplace does not see those Go CVEs. A separate SBOM file is attached to the GitHub Release by CI.

`ATTESTATIONS=full` is for a Scout supply-chain review. It can reintroduce the Marketplace Go flags.

Current builder pins: `moby/buildkit:v0.32.2`. The SBOM file on the Release is produced by Syft in Actions, not by embedding syft inside the image.

## Copyleft

Org policy “Copyleft licensed packages found” fails on hundreds of GPL/LGPL Debian packages. That is this stack. The release script ignores `copyleft-license`.

## Monitor

```bash
docker scout cves debian:13-slim --only-severity critical
make cves-critical
docker scout cves abstechnology/moodle-standard:$(grep DOCKER_TAG versions.lock | awk '{print $3}') \
  --only-severity critical --only-fixed
```

When `trixie-security` publishes a fix for a raw critical we still list:

1. Bump `DOCKER_TAG` in `versions.lock`.
2. Publish `rN` through Actions (or break-glass `make push`).
3. Update this file.
