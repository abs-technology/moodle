#!/usr/bin/env bash
# Print one key from a Terraform tfvars file (key = "value").
set -euo pipefail
key="${1:?usage: tfvars-get.sh KEY FILE}"
file="${2:?usage: tfvars-get.sh KEY FILE}"
if [[ ! -f "$file" ]]; then
  echo "missing $file" >&2
  exit 1
fi
sed -nE "s/^${key}[[:space:]]*=[[:space:]]*\"([^\"]+)\".*/\1/p" "$file" | head -n1
