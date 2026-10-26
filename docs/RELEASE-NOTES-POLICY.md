# Release notes (required on push)

For this repo, **every push that ships a new image tag or version must include Release notes**.
Do not treat Actions publish, Hub push, or git tag push as done until notes exist.

## When this applies

- GitHub Actions release on tag `v<DOCKER_TAG>` (normal path) or break-glass `make push`
- Bump `DOCKER_TAG` or Moodle pin in `versions.lock`
- Annotated git tag `v*` (e.g. `v5.3.0`)
- Promote release branch → `main`
- Marketplace / Hub submission of a new tag

Skip only for pure docs/chore commits with **no** new `DOCKER_TAG` and **no** image push.

## Hard gate

1. Read `versions.lock` (`MOODLE_VERSION`, `DOCKER_TAG`, `PHP_VERSION` or `PHP_RELEASE`, download URL).
2. One commit for the image change, in the commit shape below.
3. Push the annotated tag. Actions builds both platforms, Scouts fixable C/H, pushes Hub, signs the digest, and attaches the SBOM. Break-glass is `make push` (see [RUNBOOK.md](RUNBOOK.md)). Record the index digest. Manifest is `linux/amd64` and `linux/arm64` only.
4. Annotated git tag, plain text, shape below. Tag name is `v<DOCKER_TAG>`.
5. GitHub Release. **Title is the tag name** (`v5.3.0-r3`), not a sentence. Body is the markdown shape below.
6. Do not retag `latest` or overwrite a published tag.

The tag annotation and the GitHub body are two fixed shapes of the same facts. Do not paste one into the other.

## Tag naming

| Change | `DOCKER_TAG` | Git tag | GitHub title | Body heading |
|--------|----------------|---------|--------------|--------------|
| New Moodle pin | `5.3.0` | `v5.3.0` | `v5.3.0` | `## Moodle 5.3.0 image` |
| Image revision | `5.3.0-rN` | `v5.3.0-rN` | `v5.3.0-rN` | `## Moodle 5.3.0 image rN` |

Image: `abstechnology/moodle-standard:<DOCKER_TAG>`

Tag annotation first line for a pin is `Moodle <version> image release`. For a revision it is `Moodle <version> image revision rN`. The GitHub heading drops the words `release` and `revision`.

## Commit

Subject is one imperative sentence with a period. Body is one or two sentences on why. No type prefix (`feat:`, `fix:`). No attribution trailer.

```
Pin PHP 8.4.27 on the Moodle 5.3 image.

8.4.27 fixes CVE-2026-109618 and CVE-2026-109619. Session upload progress stays off until PHP ships the follow-up fix.
```

## Annotated tag

Plain text. No markdown, no bold, no fences. Sections are `Highlights`, `Ops`, `Pull`, in that order. Security facts go under `Highlights`.

```
Moodle 5.3.0 image revision r3

Image: abstechnology/moodle-standard:5.3.0-r3
Git tag: v5.3.0-r3
Base: Moodle 5.3.0 · PHP 8.4.27 · debian:13-slim
Source: https://packaging.moodle.org/stable503/moodle-5.3.tgz
Digest: sha256:<index>

Highlights
- PHP 8.4.27 fixes CVE-2026-109618 and CVE-2026-109619 (unauthenticated RCE).
- session.upload_progress.enabled=0 until PHP ships the CVE-2026-115560 bugfix.

Ops
- Multi-arch linux/amd64 + linux/arm64, ATTESTATIONS=none.
- Scout policy gate passed before Hub push.
- 5.3.0, 5.3.0-r1, 5.3.0-r2 and latest were not retagged.

Pull
docker pull abstechnology/moodle-standard:5.3.0-r3
```

## GitHub Release

`gh release create <tag> --title "<tag>"`. Body:

````markdown
## Moodle 5.3.0 image r3

**Image:** `abstechnology/moodle-standard:5.3.0-r3`
**Git tag:** `v5.3.0-r3`
**Base:** Moodle **5.3.0** · PHP **8.4.27** · `debian:13-slim`
**Source:** https://packaging.moodle.org/stable503/moodle-5.3.tgz
**Digest:** `sha256:<index>`

### Highlights
- …

### Security / Scout
- Scout policy gate passed before Hub push.
- …

### Ops
- Multi-arch: `linux/amd64` + `linux/arm64`
- `ATTESTATIONS=none`
- `5.3.0`, `5.3.0-r1`, `5.3.0-r2` and `latest` were not retagged

### Pull
```bash
docker pull abstechnology/moodle-standard:5.3.0-r3
```
````

Ops is those three bullets, each on its own line. List every published tag that was left in place, then `latest`.

## Checklist

- [ ] `versions.lock` read; `DOCKER_TAG` matches image, compose, and docs mirrors
- [ ] Commit subject matches the shape above
- [ ] Actions (or break-glass `make push`) OK; digest recorded; amd64 + arm64 only; SBOM on the GitHub Release
- [ ] Annotated tag is plain text; GitHub title equals the tag name
- [ ] GitHub body heading is `Moodle <version> image` or `Moodle <version> image rN`
- [ ] No agent attribution in commit, tag, or release
