# Manual Moodle deploy (after Terraform infra)

Terraform provisions GCP only. Install Moodle with Helm when you are ready.

```bash
cd gke-moodle
make apply
make output
eval "$(terraform -chdir=terraform/live output -raw connect)"
```

Cert for `moodle.<ip>.nip.io` stays PROVISIONING until a Gateway serves that host.

## 1. Namespace, secret, Workload Identity

KSA name **must** stay `moodle` in namespace `moodle` (WI binding is already in Terraform).

```bash
NS=moodle
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl label ns "$NS" pod-security.kubernetes.io/enforce=baseline app=moodle --overwrite

DB_PASS="$(terraform -chdir=terraform/live output -raw moodle_db_password)"
ADMIN_PASS="$(terraform -chdir=terraform/live output -raw moodle_admin_password)"
kubectl -n "$NS" create secret generic moodle \
  --from-literal=MOODLE_DATABASE_PASSWORD="$DB_PASS" \
  --from-literal=MOODLE_PASSWORD="$ADMIN_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## 2. Filestore PV + PVC (default)

Skip if `storage_backend = "pd"` — create a GCE PD PVC yourself (`standard-rwo`).

```bash
FS_IP="$(terraform -chdir=terraform/live output -json filestore | python3 -c 'import json,sys; print(json.load(sys.stdin)["ip"])')"
FS_PATH="$(terraform -chdir=terraform/live output -json filestore | python3 -c 'import json,sys; print(json.load(sys.stdin)["nfs_path"])')"
FS_GB="$(terraform -chdir=terraform/live output -json filestore | python3 -c 'import json,sys; print(json.load(sys.stdin)["capacity_gb"])')"

kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: moodle-filestore
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: moodle-moodledata
spec:
  capacity:
    storage: ${FS_GB}Gi
  accessModes: ["ReadWriteMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: moodle-filestore
  mountOptions: ["nfsvers=3", "nolock"]
  claimRef:
    namespace: moodle
    name: moodle-data
  nfs:
    server: ${FS_IP}
    path: ${FS_PATH}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: moodle-data
  namespace: moodle
spec:
  accessModes: ["ReadWriteMany"]
  storageClassName: moodle-filestore
  volumeName: moodle-moodledata
  resources:
    requests:
      storage: ${FS_GB}Gi
EOF
```

## 3. Helm values overlay

```bash
terraform -chdir=terraform/live output -json helm_values \
  | python3 -c 'import json,sys,yaml; print(yaml.safe_dump(json.load(sys.stdin), sort_keys=False))' \
  > /tmp/moodle-overlay.yaml
```

If you do not have PyYAML:

```bash
terraform -chdir=terraform/live output -json helm_values > /tmp/moodle-overlay.json
```

Autoscaling defaults to `none` (fixed `replicaCount`). Optional KEDA:

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm upgrade --install keda kedacore/keda --namespace keda --create-namespace --version 2.16.1
```

Then set `autoscaling.mode: keda` in the overlay. `hpa` needs no extra CRDs.

## 4. Install Moodle

```bash
make sync-overlays
helm upgrade --install moodle ./charts/moodle \
  --namespace moodle \
  --values /tmp/moodle-overlay.yaml \
  --wait --timeout 30m
```

```bash
kubectl -n moodle get deploy,po,svc,gateway,httproute
curl -sS "$(terraform -chdir=terraform/live output -raw site_url)/readyz"
```

Admin: `admin` / `terraform -chdir=terraform/live output -raw moodle_admin_password`.

## Later

Grafana, uptime SLO, and putting Helm back under Terraform wait until this install is stable. Chart overlays stay the Hub/GKE contract (`make sync-overlays`). Do not `kubectl patch` the Deployment.
