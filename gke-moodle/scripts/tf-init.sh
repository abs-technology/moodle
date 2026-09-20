#!/usr/bin/env bash
# Bootstrap the GCS state bucket, then terraform init live.
#
# Single source of project: terraform/live/terraform.tfvars
# Credentials: Application Default Credentials (no key file).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TFVARS="$ROOT/terraform/live/terraform.tfvars"
BOOT="$ROOT/terraform/bootstrap"
LIVE="$ROOT/terraform/live"
GET="$ROOT/scripts/tfvars-get.sh"

if [[ ! -f "$TFVARS" ]]; then
  echo "copy terraform/live/terraform.tfvars.example to terraform.tfvars" >&2
  exit 1
fi

project_id="$("$GET" project_id "$TFVARS")"
region="$("$GET" region "$TFVARS")"
region="${region:-asia-southeast1}"

if [[ -z "$project_id" || "$project_id" == "your-gcp-project" ]]; then
  echo "set project_id in $TFVARS" >&2
  exit 1
fi

if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "ADC missing. Run: gcloud auth application-default login" >&2
  exit 1
fi

# This process only — do not require `gcloud config set project`.
export GOOGLE_CLOUD_PROJECT="$project_id"
export CLOUDSDK_CORE_PROJECT="$project_id"
export GOOGLE_CLOUD_QUOTA_PROJECT="$project_id"
export CLOUDSDK_BILLING_PROJECT="$project_id"

bucket="${project_id}-moodle-gke-tfstate"
state_dir="$BOOT/.states/${project_id}"
mkdir -p "$state_dir"

# Leftover implicit local state from before per-project backends.
if [[ -f "$BOOT/terraform.tfstate" ]]; then
  echo "==> moving leftover bootstrap/terraform.tfstate aside (not used)"
  mv "$BOOT/terraform.tfstate" "$BOOT/terraform.tfstate.legacy"
  if [[ -f "$BOOT/terraform.tfstate.backup" ]]; then
    mv "$BOOT/terraform.tfstate.backup" "$BOOT/terraform.tfstate.backup.legacy"
  fi
fi

echo "==> bootstrap  project=${project_id}  bucket=gs://${bucket}"
echo "    ADC credentials; project from ${TFVARS}"
terraform -chdir="$BOOT" init -input=false -reconfigure \
  -backend-config="path=.states/${project_id}/terraform.tfstate"
terraform -chdir="$BOOT" apply -input=false -auto-approve \
  -var="project_id=${project_id}" \
  -var="location=${region}"

echo "==> live init  backend=gs://${bucket}  prefix=gke-moodle/live"
terraform -chdir="$LIVE" init -input=false -reconfigure \
  -backend-config="bucket=${bucket}"
