---
name: no-cursor-repo-leak
description: >-
  Blocks Cursor attribution, agent trailers, checkpoint commits, and Cursor/agent
  log artifacts from entering the abs-technology/moodle git history or tree. Use
  before every git commit, git push, gh pr create, tag, or release; also when the
  user mentions Cursor logs, Co-authored-by Cursor, cursoragent, Made-with Cursor,
  or scrubbing AI attribution from this repo.
---

# No Cursor leak in this repo

This repository must **never** publish Cursor identity, attribution, agent logs, or checkpoint noise.

## Why it appeared

Cursor Agent **Attribution** (on by default) appends trailers such as:

```text
Co-authored-by: Cursor <cursoragent@cursor.com>
```

or `Made-with: Cursor` to commits / PRs the agent creates. That is **not** a file under the tree — it is injected into the **git commit / PR message**. Older history may also contain `[Cursor] Checkpoint at …` commits from Cursor checkpoints.

Treat any of that as a **security / compliance leak** for this product repo.

## Hard bans (never allow)

Never add, keep, commit, or push:

- `Co-authored-by: Cursor` / `cursoragent@cursor.com` / `Made-with: Cursor` / `Made with Cursor`
- Commit subjects like `[Cursor] Checkpoint …`
- Author/committer `Cursor Agent` / `cursoragent@cursor.com` when avoidable
- Agent transcripts, chat exports, `.cursor` debug logs, local Cursor caches
- Mentions of Cursor agent internals in Release notes, PR bodies, or commit bodies

Allowed under `.cursor/` **only**: intentional project skills/rules committed for the team (this skill, release-notes skill, rules). Nothing else.

## Before every `git commit`

1. Draft the message **without** any Cursor trailer.
2. Prefer committing via shell with an explicit HEREDOC message (never rely on Cursor auto-attribution).
3. Install / ensure hooks (once per clone):

```bash
./scripts/git-hooks/install.sh
```

4. After commit, verify:

```bash
git log -1 --format=%B | rg -i 'cursoragent|co-authored-by:\s*cursor|made-with:\s*cursor|\[cursor\]' && echo FAIL || echo OK
```

If FAIL: **do not push**. Amend only when amend rules allow; otherwise `git reset --soft HEAD~1`, recommit clean, or create a **new** clean commit. Prefer new commit over rewrite of already-pushed history.

## Before every `git push` / PR / release

Scan commits about to leave the machine:

```bash
git log --format='%H%n%s%n%b%n---' @{upstream}..HEAD 2>/dev/null || git log --format='%H%n%s%n%b%n---' origin/$(git rev-parse --abbrev-ref HEAD)..HEAD
```

Reject push if any match:

- `cursoragent@cursor.com`
- `Co-authored-by:.*Cursor`
- `Made-with:\s*Cursor`
- `^\[Cursor\]`

Also reject if staged/untracked junk matches:

```bash
rg -l -i 'cursoragent|agent-transcript' --glob '!.cursor/skills/**' --glob '!.cursor/rules/**' || true
```

## Strip helpers

Hooks live in `scripts/git-hooks/`:

| Hook | Role |
|------|------|
| `prepare-commit-msg` | Strip Cursor attribution lines from the commit message file |
| `commit-msg` | **Fail** the commit if Cursor attribution remains |
| `install.sh` | Symlink hooks into `.git/hooks/` |

Run `./scripts/git-hooks/install.sh` at the start of any session that will commit.

## User IDE / CLI (tell user once per clone)

Ask the user to turn off Attribution (agent cannot reliably change this alone):

- Cursor Settings → **Agent** / **Git & PRs** → **Attribution** → off (commits + PRs)
- CLI: `~/.cursor/cli-config.json` → disable agent commit/PR attribution flags if present

Hooks remain mandatory even if settings are off (settings are often ignored by cloud/background agents).

## History already polluted

Do **not** rewrite `main` / published tags unless the user **explicitly** requests a history rewrite and force-push.

If asked to scrub history: list affected SHAs, propose a filter-repo / rebase plan, warn about force-push and tag moves, and wait for explicit approval.

## Checklist

```
- [ ] No Cursor trailer in commit message
- [ ] hooks installed (./scripts/git-hooks/install.sh)
- [ ] post-commit message scan OK
- [ ] pre-push range scan OK
- [ ] no agent transcripts / Cursor logs staged
- [ ] PR body has no Cursor attribution
```
