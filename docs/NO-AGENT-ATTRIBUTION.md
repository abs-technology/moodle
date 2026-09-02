# No AI-editor attribution in this repo

This repository must **never** publish AI-editor identity, attribution trailers, checkpoint noise, or IDE config trees.

## Hard bans

Never add, keep, commit, or push:

- Commit/PR trailers such as `Co-authored-by: Cursor <cursoragent@cursor.com>`, `Made-with: Cursor`, or equivalent agent co-author lines
- Commit subjects like `[Cursor] Checkpoint …`
- Agent transcripts, chat exports, IDE debug logs, local IDE caches
- The **`.cursor/`** directory (or similar IDE folders) in git — policies live in `docs/` + `AGENTS.md` + `scripts/git-hooks/` only

## Why trailers appeared

Some AI editors append attribution trailers to commits/PRs by default. That lands in **git message history**, not as a normal source file. Treat it as a compliance leak.

## Before every commit

1. Write the message with an explicit HEREDOC — no auto attribution.
2. Ensure hooks are installed:

```bash
./scripts/git-hooks/install.sh
```

3. Verify:

```bash
git log -1 --format=%B | rg -i 'cursoragent|co-authored-by:\s*cursor|made-with:\s*cursor|\[cursor\]' && echo FAIL || echo OK
```

## Before every push / PR / release

Reject if the range to push matches `cursoragent@…`, `Co-authored-by: …Cursor`, `Made-with: Cursor`, or `^[Cursor]`.

Reject if `.cursor/` or agent transcripts are staged.

## Hooks

| Hook | Role |
|------|------|
| `scripts/git-hooks/prepare-commit-msg` | Strip banned attribution lines |
| `scripts/git-hooks/commit-msg` | Fail commit if they remain |
| `scripts/git-hooks/install.sh` | Install into `.git/hooks/` |

## Checklist

- [ ] No agent attribution trailer in commit / PR body
- [ ] Hooks installed
- [ ] No `.cursor/` or IDE junk staged
- [ ] Message scan OK before push
