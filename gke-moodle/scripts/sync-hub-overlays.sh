#!/usr/bin/env bash
# Copy image scripts the GKE chart overlays onto the Hub image.
# Hub 5.2.3 is VM/Marketplace-oriented; these files are the contract.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="${ROOT}/gke-moodle/charts/moodle/files"
CHECK=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK=1
fi

mkdir -p "$DEST"

pairs=(
  "scripts/entrypoint.sh:entrypoint.sh"
  "scripts/setup/moodle.sh:moodle.sh"
  "scripts/setup/mariadb.sh:mariadb.sh"
  "scripts/lib/mariadb.sh:mariadb-lib.sh"
  "scripts/moodle-run.sh:moodle-run.sh"
)

stale=0
for pair in "${pairs[@]}"; do
  src="${ROOT}/${pair%%:*}"
  dst="${DEST}/${pair##*:}"
  if [[ ! -f "$src" ]]; then
    echo "missing source ${src}" >&2
    exit 1
  fi
  if [[ "$CHECK" -eq 1 ]]; then
    if ! cmp -s "$src" "$dst"; then
      echo "out of date: ${dst} (run gke-moodle/scripts/sync-hub-overlays.sh)" >&2
      stale=1
    fi
  else
    cp "$src" "$dst"
    echo "synced ${pair##*:}"
  fi
done

if [[ "$stale" -eq 1 ]]; then
  exit 1
fi
