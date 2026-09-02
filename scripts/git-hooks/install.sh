#!/usr/bin/env bash
# Install repo git hooks that strip/block Cursor attribution.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK_DIR="$ROOT/.git/hooks"
SRC_DIR="$ROOT/scripts/git-hooks"

if [[ ! -d "$ROOT/.git" ]]; then
  echo "Not a git repo: $ROOT" >&2
  exit 1
fi

mkdir -p "$HOOK_DIR"
for hook in prepare-commit-msg commit-msg; do
  src="$SRC_DIR/$hook"
  dst="$HOOK_DIR/$hook"
  if [[ ! -f "$src" ]]; then
    echo "Missing $src" >&2
    exit 1
  fi
  chmod +x "$src"
  # Copy (not symlink) so hooks work when core.hooksPath is unset and across clones.
  cp "$src" "$dst"
  chmod +x "$dst"
  echo "Installed $dst"
done

echo "OK: Cursor attribution hooks installed."
