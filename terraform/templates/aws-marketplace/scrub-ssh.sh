#!/usr/bin/env bash
# Run as root (SSM). Marketplace rejects builder authorized_keys in the AMI.
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/building-shared-amis.html
set -euo pipefail

scrub_dir() {
  local d="$1"
  [[ -d "$d" ]] || return 0
  local f
  while IFS= read -r -d '' f; do
    echo "remove $f"
    rm -f "$f"
  done < <(find "$d" -maxdepth 1 -type f -name 'authorized_keys*' -print0 2>/dev/null)
}

scrub_dir /root/.ssh
scrub_dir /home/admin/.ssh
scrub_dir /home/ubuntu/.ssh
if [[ -d /home ]]; then
  for d in /home/*/.ssh; do
    scrub_dir "$d"
  done
fi

echo "authorized_keys scrub done"
