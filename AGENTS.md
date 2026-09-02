# Agent / maintainer policies

Do **not** commit IDE folders such as `.cursor/` into this repository.

Read and follow:

- [docs/RELEASE-NOTES-POLICY.md](docs/RELEASE-NOTES-POLICY.md) — required on every image/version push
- [docs/NO-AGENT-ATTRIBUTION.md](docs/NO-AGENT-ATTRIBUTION.md) — never publish AI-editor attribution trailers or IDE junk

Install git hooks once per clone:

```bash
./scripts/git-hooks/install.sh
```
