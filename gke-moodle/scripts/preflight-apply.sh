#!/usr/bin/env bash
# Catch leftover names / scheduled-deletion secrets before terraform apply.
# Does not delete live infra. Undeletes + imports Secret Manager secrets so
# apply does not 409 (destroy leaves names reserved ~7 days).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TFVARS="$ROOT/terraform/live/terraform.tfvars"
LIVE="$ROOT/terraform/live"
GET="$ROOT/scripts/tfvars-get.sh"

if [[ ! -f "$TFVARS" ]]; then
  echo "copy terraform/live/terraform.tfvars.example to terraform.tfvars" >&2
  exit 1
fi

project_id="$("$GET" project_id "$TFVARS")"
region="$("$GET" region "$TFVARS")"
region="${region:-asia-southeast1}"
name="$("$GET" name "$TFVARS")"
name="${name:-moodle}"
zone="$("$GET" zone "$TFVARS")"

if [[ -z "$project_id" || "$project_id" == "your-gcp-project" ]]; then
  echo "set project_id in $TFVARS" >&2
  exit 1
fi

if grep -q '^keda_chart_version' "$TFVARS"; then
  echo "remove keda_chart_version from $TFVARS (variable was deleted)" >&2
  exit 1
fi

if grep -Eq '^deletion_protection[[:space:]]*=[[:space:]]*false' "$TFVARS"; then
  echo "warning: deletion_protection=false — a later destroy will wipe GKE + Cloud SQL + Filestore" >&2
fi

echo "==> project ${project_id}  name=${name}  region=${region}  zone=${zone}"
if ! gcloud projects describe "$project_id" --format='value(projectId)' >/dev/null; then
  echo "gcloud cannot read project ${project_id}. Run: gcloud auth login && gcloud auth application-default login" >&2
  exit 1
fi
gcloud config set project "$project_id" >/dev/null

command -v gcloud >/dev/null
command -v python3 >/dev/null
command -v terraform >/dev/null

tf_ready=0
if [[ -d "$LIVE/.terraform" ]]; then
  tf_ready=1
fi

import_secret() {
  local addr="$1"
  local sid="$2"
  if [[ "$tf_ready" -ne 1 ]]; then
    echo "    run make init, then: terraform -chdir=terraform/live import '${addr}' 'projects/${project_id}/secrets/${sid}'"
    return
  fi
  if terraform -chdir="$LIVE" state list 2>/dev/null | grep -qx "$addr"; then
    echo "    ${sid}: already in state"
    return
  fi
  echo "    import ${addr}"
  terraform -chdir="$LIVE" import -input=false "$addr" "projects/${project_id}/secrets/${sid}"
}

# Secret Manager: destroy leaves the id reserved. Create 409s until undelete+import.
prepare_secret() {
  local sid="$1"
  local addr="$2"
  local state
  state="$(gcloud secrets describe "$sid" --project="$project_id" --format='value(state)' 2>/dev/null || true)"
  if [[ -z "$state" ]]; then
    echo "    secret ${sid}: absent (ok)"
    return
  fi
  if [[ "$state" == "DESTROYED" ]]; then
    echo "    secret ${sid}: DESTROYED → undelete"
    gcloud secrets undelete "$sid" --project="$project_id" --quiet
  else
    echo "    secret ${sid}: ${state}"
  fi
  import_secret "$addr" "$sid"
}

echo "==> secrets"
prepare_secret "${name}-db-password" "module.secrets.google_secret_manager_secret.db"
prepare_secret "${name}-admin-password" "module.secrets.google_secret_manager_secret.admin"

collide=0
note() {
  echo "    leftover: $1"
  collide=1
}

echo "==> leftover names that would 409 on create"
gcloud container clusters describe "$name" --region="$region" --project="$project_id" --format='value(name)' >/dev/null 2>&1 \
  && note "GKE cluster ${name}"

gcloud compute networks describe "${name}-vpc" --project="$project_id" --format='value(name)' >/dev/null 2>&1 \
  && note "VPC ${name}-vpc"

gcloud compute addresses describe "${name}-alb" --global --project="$project_id" --format='value(name)' >/dev/null 2>&1 \
  && note "global IP ${name}-alb"

gcloud compute addresses describe "${name}-sql-peering" --global --project="$project_id" --format='value(name)' >/dev/null 2>&1 \
  && note "PSA range ${name}-sql-peering"

gcloud compute security-policies describe "${name}-armor" --project="$project_id" --format='value(name)' >/dev/null 2>&1 \
  && note "Cloud Armor ${name}-armor"

gcloud certificate-manager maps describe "${name}-certmap" --project="$project_id" --format='value(name)' >/dev/null 2>&1 \
  && note "cert map ${name}-certmap"

gcloud certificate-manager certificates describe "${name}-cert" --project="$project_id" --format='value(name)' >/dev/null 2>&1 \
  && note "cert ${name}-cert"

gcloud artifacts repositories describe moodle --location="$region" --project="$project_id" --format='value(name)' >/dev/null 2>&1 \
  && note "Artifact Registry ${region}/moodle"

gcloud filestore instances describe "${name}-fs" --zone="$zone" --project="$project_id" --format='value(name)' >/dev/null 2>&1 \
  && note "Filestore ${name}-fs (${zone})"
# Previous apply used asia-southeast1-a; check both if zone changed.
if [[ "$zone" != "asia-southeast1-a" ]]; then
  gcloud filestore instances describe "${name}-fs" --zone="asia-southeast1-a" --project="$project_id" --format='value(name)' >/dev/null 2>&1 \
    && note "Filestore ${name}-fs (asia-southeast1-a)"
fi

gcloud iam service-accounts describe "${name}-ksa@${project_id}.iam.gserviceaccount.com" --project="$project_id" --format='value(email)' >/dev/null 2>&1 \
  && note "GSA ${name}-ksa"

gcloud iam service-accounts describe "${name}-gke-nodes@${project_id}.iam.gserviceaccount.com" --project="$project_id" --format='value(email)' >/dev/null 2>&1 \
  && note "GSA ${name}-gke-nodes"

sql_hits="$(gcloud sql instances list --project="$project_id" --filter="name~^${name}-" --format='value(name)' 2>/dev/null || true)"
if [[ -n "$sql_hits" ]]; then
  note "Cloud SQL: ${sql_hits}"
fi

if gcloud compute networks describe "${name}-vpc" --project="$project_id" >/dev/null 2>&1; then
  peer="$(gcloud compute networks peerings list --network="${name}-vpc" --project="$project_id" --format='value(peer.name)' 2>/dev/null || true)"
  if [[ -n "$peer" ]]; then
    note "VPC peerings on ${name}-vpc: ${peer}"
  fi
fi

if [[ "$collide" -ne 0 ]]; then
  echo >&2
  echo "leftover names above will make terraform apply fail with already-exists." >&2
  echo "delete them (or terraform import) before apply. do not delete ip-alb-moodle." >&2
  exit 1
fi

echo "==> clean. apply when ready: cd gke-moodle && make apply"
echo "    first apply 20–40 min. do not Ctrl+Z terraform."
