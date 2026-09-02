# Release notes (required on push)

For this repo, **every push that ships a new image tag or version must include Release notes**.
Do not treat `make push`, Hub push, or git tag push as done until notes exist.

## When this applies

- `make push` / Docker Hub push of `abstechnology/moodle-standard`
- Bump `DOCKER_TAG` or Moodle pin in `versions.lock`
- Annotated git tag `v*` (e.g. `v5.2.2-r2`)
- Promote release branch → `main`
- Marketplace / Hub submission of a new tag

Skip only for pure docs/chore commits with **no** new `DOCKER_TAG` and **no** image push.

## Hard gate

1. Read `versions.lock` (`MOODLE_VERSION`, `DOCKER_TAG`, `PHP_VERSION`, download URL).
2. Draft Release notes from commits since previous related tag + security/ops notes.
3. Show notes to the user; adjust if they ask.
4. Attach notes to **both** annotated git tag and GitHub Release body.
5. Then push image / tag / branch as requested.

## Tag naming

| Change | `DOCKER_TAG` / git tag |
|--------|-------------------------|
| New Moodle upstream pin | `5.2.2` → git `v5.2.2` |
| Same Moodle, image revision | `5.2.2-r1`, `5.2.2-r2` → git `v5.2.2-r2` |

Image: `abstechnology/moodle-standard:<DOCKER_TAG>`

## Template

```markdown
## Moodle <MOODLE_VERSION> image <revision or "release pin">

**Image:** `abstechnology/moodle-standard:<DOCKER_TAG>`
**Git tag:** `v<DOCKER_TAG>`
**Base:** Moodle **<MOODLE_VERSION>** · PHP **<PHP_VERSION>**
**Source:** <MOODLE_DOWNLOAD_URL>

### Highlights
- …

### Security / Scout
- …

### Ops
- …

### Pull
```bash
docker pull abstechnology/moodle-standard:<DOCKER_TAG>
```
```

## Checklist

- [ ] `versions.lock` read; `DOCKER_TAG` matches image
- [ ] Release notes drafted
- [ ] Image push (if requested) OK
- [ ] Annotated tag + GitHub Release with notes
- [ ] Hub digest / arch / attestation checked when Marketplace-sensitive
