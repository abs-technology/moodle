---
name: moodle-release-notes
description: >-
  Requires Release notes for every image or version push of abs-technology/moodle
  (abstechnology/moodle-standard). Use when the user asks to make push, docker push,
  tag a release, bump DOCKER_TAG / versions.lock, promote to main, publish Hub/Marketplace
  image, or create a GitHub Release.
---

# Moodle release notes (required on push)

For this repo, **every push that ships a new image tag or version must include Release notes**.
Do not treat `make push`, Hub push, or git tag push as done until notes exist.

## When this applies

Trigger on any of:

- `make push` / Docker Hub push of `abstechnology/moodle-standard`
- Bump `DOCKER_TAG` or Moodle pin in `versions.lock`
- Annotated git tag `v*` (e.g. `v5.2.2-r2`)
- Promote release branch → `main`
- Marketplace / Hub submission of a new tag

Skip only for pure docs/chore commits with **no** new `DOCKER_TAG` and **no** image push.

## Hard gate

Before push completes:

1. Read `versions.lock` (source of truth: `MOODLE_VERSION`, `DOCKER_TAG`, `PHP_VERSION`, download URL).
2. Draft Release notes (template below) from:
   - commits since previous related tag (`git log <prev>..<HEAD>`)
   - security pins / Scout / Marketplace changes
   - compose/docs behavior that operators need
3. Show notes to the user; adjust if they ask.
4. Attach notes to **both**:
   - annotated git tag message (`git tag -a`)
   - GitHub Release body (`gh release create … --notes` or `--notes-file`)
5. Then push image / tag / branch as requested.

If the user says “push” without mentioning notes, **still** produce Release notes and ask once to confirm before creating the GitHub Release.

## Tag naming

| Change | `DOCKER_TAG` / git tag |
|--------|-------------------------|
| New Moodle upstream pin | `5.2.2` → git `v5.2.2` |
| Same Moodle, image revision | `5.2.2-r1`, `5.2.2-r2` → git `v5.2.2-r2` |

Image: `abstechnology/moodle-standard:<DOCKER_TAG>`  
Also retag aliases when that is the release intent: `5.2.2`, `5.2`, `latest` (only if `versions.lock` / Makefile say so).

## Release notes template

Use this structure (fill from `versions.lock` + git log):

```markdown
## Moodle <MOODLE_VERSION> image <revision or "release pin">

**Image:** `abstechnology/moodle-standard:<DOCKER_TAG>`
**Git tag:** `v<DOCKER_TAG>`
**Base:** Moodle **<MOODLE_VERSION>** · PHP **<PHP_VERSION>**
**Source:** <MOODLE_DOWNLOAD_URL>

### Highlights
- <user-facing / security / Marketplace items — bullets>

### Security / Scout
- <CVE pins, attestation policy, Scout gate notes — or "none">

### Ops
- <compose, first-boot, make targets, removed tooling — or omit section>

### Pull
```bash
docker pull abstechnology/moodle-standard:<DOCKER_TAG>
```
```

Annotated tag message may be a **short** form of the same content (title + image + 2–5 bullets). GitHub Release body should use the **full** template.

## Commands (after notes approved)

```bash
# 1) Annotated tag (notes in message)
git tag -a "v${DOCKER_TAG}" -m "$(cat <<'EOF'
<short release notes>
EOF
)"

# 2) Push tag
git push origin "v${DOCKER_TAG}"

# 3) GitHub Release (full notes)
gh release create "v${DOCKER_TAG}" \
  --title "Moodle ${MOODLE_VERSION} (${DOCKER_TAG})" \
  --notes "$(cat <<'EOF'
<full release notes markdown>
EOF
)"
```

If tag already exists remote but Release is missing: create Release only (`gh release create`), do not retag unless user asks.

## Checklist

```
- [ ] versions.lock read; DOCKER_TAG matches image being pushed
- [ ] Release notes drafted + user-visible
- [ ] Image push (if requested) succeeded
- [ ] Annotated tag created with short notes
- [ ] Tag pushed to origin
- [ ] GitHub Release created with full notes
- [ ] Hub digest / arch / attestation verified when Marketplace-sensitive
```

## Example (v5.2.2-r2)

Short tag message:

```text
Moodle 5.2.2 image revision r2 (Marketplace-safe)

Image: abstechnology/moodle-standard:5.2.2-r2
- Pin mtdowling/jmespath.php >= 2.9.1 (CVE-2026-54133)
- ATTESTATIONS=none (--provenance=false --sbom=false)
```

## Do not

- Push a new `DOCKER_TAG` without Release notes
- Lightweight tags (`git tag` without `-a`) for releases
- Force-push `main` or move published release tags unless user explicitly requests
- Commit Moodle runtime data under `data/`
