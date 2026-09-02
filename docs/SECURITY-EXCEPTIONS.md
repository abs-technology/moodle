# Security exceptions — Docker Scout critical CVEs

Image: `abstechnology/moodle-standard` (Debian 12 / bookworm base)  
Applies to: Moodle **5.2.2** and later builds on `debian:12-slim` until Debian ships fixes.

## How to read Scout numbers

| Signal | Meaning |
|--------|---------|
| Quickview **4C** (raw) | All critical CVEs, including **unfixed** in the distro |
| Policy **No fixable critical or high** | Must stay **PASS** — no C/H that already have a published fix |
| Policy **Copyleft** | Expected fail on Debian/Apache/PHP stacks; **ignored** by `make push` gate |

**Release rule:** `make push` / `scripts/utils/docker-scout.sh policy` gates on **fixable** security policies only. Raw critical counts on `make scan` are for awareness, not an automatic release blocker.

Gate policy IDs (copyleft omitted on purpose):

- `default-non-root-user`
- `fixable-vulnerabilities`
- `high-profile-vulnerabilities`
- `no-stale-base-images`
- `approved-base-images`
- `supply-chain-attestations`

## Accepted unfixable criticals (bookworm)

As of the 5.2.2 Scout review, these four criticals have **no fixed version in Debian bookworm** (`Fixed version: not fixed`). They are **risk-accepted** until `bookworm-security` (or a deliberate base upgrade) provides packages.

| CVE | Package | Image version (example) | Source | Notes |
|-----|---------|-------------------------|--------|-------|
| CVE-2026-13221 | `perl` | 5.36.0-7+deb12u3 | `debian:12-slim` | Regex trie edge cases; not a typical Moodle HTTP attack path |
| CVE-2026-12087 | `perl` (Socket) | same | `debian:12-slim` | Heap over-read via uncommon Socket API use; Debian severity often lower on stable |
| CVE-2026-34191 | `libaprutil1` | 1.6.3-1 | Apache (`apache2`) | SQLi in **apr_dbd_oracle** provider — Moodle uses **MariaDB/MySQL**, Oracle DBD normally unused |
| CVE-2026-32327 | `libaprutil1` | 1.6.3-1 | Apache (`apache2`) | Stack recursion in `apr_xml_quote_elem` on hostile XML via APR util |

**Not in this list:** PHP (Sury), Composer app deps (Guzzle/AWS are pinned in the Dockerfile for *fixable* highs).

Moving to `debian:13-slim` alone does **not** clear the perl pair (still reported critical there). It is out of scope for this exception document.

## Monitor and rebuild when Debian ships fixes

Check periodically:

```bash
# Base image criticals
docker scout cves debian:12-slim --only-severity critical

# Our image: raw criticals vs already-fixed only
make cves-critical
docker scout cves abstechnology/moodle-standard:$(grep DOCKER_TAG versions.lock | awk '{print $3}') \
  --only-severity critical --only-fixed
```

When `bookworm-security` publishes updates for **`perl`** and/or **`libaprutil1` (>= 1.6.4)**:

1. Bump image revision if needed (e.g. `DOCKER_TAG := 5.2.2-r1` in [`versions.lock`](../versions.lock) + compose/docs mirrors).
2. Rebuild and push with a fresh base pull:
   ```bash
   docker pull debian:12-slim
   make push   # NO_CACHE=yes → --pull
   ```
3. Confirm:
   - `make policy` still PASS
   - `docker scout cves … --only-severity critical --only-fixed` → empty
   - Raw critical count drops or clears for the packages above
4. Update this file: remove rows that are fixed, or mark “cleared in tag …”

## Related commands

| Command | Purpose |
|---------|---------|
| `make scan` | Quickview (raw C/H + all Hub policies) |
| `make policy` | Release gate (fixable C/H, etc.; ignores copyleft) |
| `make cves-critical` | List raw critical CVEs for manual review |
| `make fix` | Scout base-image recommendations |

## Copyleft (separate from criticals)

Org policy “Copyleft licensed packages found” fails on hundreds of GPL/LGPL Debian packages. That is inherent to this stack and is **not** addressed by fixing the four criticals above. The release script ignores `copyleft-license`. To silence Hub UI, adjust the org Scout policy in Docker Hub — do not change the OS base solely for license counts.

## Marketplace Go CVEs (attestation false positives)

Google Cloud Marketplace / Artifact Analysis may reject an image with messages like:

| CVE | Package | Type | Typical source |
|-----|---------|------|----------------|
| CVE-2026-53492 / CVE-2026-50195 | `github.com/containerd/containerd/v2` @ 2.2.3 (fix ≥ 2.2.5) | GO | BuildKit / SBOM generator metadata |
| CVE-2023-24531 | Go `toolchain` @ 1.18.2 (fix ≥ 1.21) | GO_STDLIB | Old BuildKit provenance tooling |

These packages are **not** part of the Moodle/PHP runtime. They appear when the submitted OCI index includes **SBOM/provenance attestation** manifests (`platform: unknown/unknown`) produced by `docker buildx` with `--attest`.

Builds are **local only** (`make push` / `make build`). Cloud Build / `cloudbuild.yaml` has been removed.

### Một lần `make push` — một image

Mặc định **`ATTESTATIONS=none`**: image không có SBOM/provenance → Marketplace không còn flag Go/containerd từ attestation, và vẫn dùng cùng tag trên Docker Hub.

```bash
make login
make push          # Scout gate (bỏ supply-chain attest) → multi-arch push
make inspect-manifest   # xác nhận không có unknown/unknown
```

Chỉ bật attestation khi cố ý (Scout supply-chain đầy đủ; Marketplace có thể cảnh báo lại):

```bash
ATTESTATIONS=full make push
```

### After changing BuildKit / SBOM pins

```bash
docker buildx rm scout-builder || true
make push   # recreates builder with BUILDKIT_IMAGE / SBOM_SCANNER from docker-scout.sh
```

Current pins (defaults in `scripts/utils/docker-scout.sh`): `moby/buildkit:v0.32.2`, `docker/buildkit-syft-scanner:latest`.
