# Moodle on GKE

Independent of [`terraform/`](../terraform/) (VM / Marketplace).

**Terraform owns GCP infrastructure only.** Moodle (Helm), Grafana, and KEDA
are installed by hand — see [docs/DEPLOY.md](docs/DEPLOY.md).

AWS / EKS is out of scope here.

## What Terraform creates

| Layer | Choice |
|---|---|
| Cluster | GKE **Standard**, regional, min 3 nodes across 3 zones, private nodes, Dataplane V2, Workload Identity, Managed Prometheus |
| Database | Cloud SQL **Enterprise Plus**, **MySQL 8.4**, `db-perf-optimized-N-8`, 100 GiB SSD, REGIONAL HA, PITR, **no public IP** |
| Files | **Default:** Filestore NFS (~1 TiB). **Optional:** skip Filestore (`storage_backend = "pd"`) and attach a GCE PD PVC yourself |
| Edge | Reserved global IP, Certificate Manager (`moodle.<ip>.nip.io`), Cloud Armor policy |
| Identity | Moodle GSA + Cloud SQL client + WI binding for `moodle/moodle` |
| Secrets | Secret Manager (`moodle-db-password`, `moodle-admin-password`) |
| Supply chain | Artifact Registry + optional Binary Authorization |
| Signals | Cloud SQL CPU alert + infra dashboard |

Helm chart `charts/moodle` is for **manual** `helm upgrade --install` against
`abstechnology/moodle-standard`. Not the Bitnami chart.

## Apply infra

Needs `gcloud` ADC (`gcloud auth application-default login`), billing, and
enough quota (Enterprise Plus + Filestore 1 TiB + regional GKE).

```bash
cd gke-moodle
# terraform/live/terraform.tfvars (copy from terraform.tfvars.example).

# project_id only in terraform/live/terraform.tfvars
# gcloud auth application-default login
make init
# bootstrap uses ADC; bucket gs://<project_id>-moodle-gke-tfstate
# live backend is that bucket (switch project = -reconfigure, no migrate)
make preflight
make apply
make output
```

First apply: cluster + SQL + Filestore take 20–40 minutes. Then
[deploy Moodle](docs/DEPLOY.md).

```bash
terraform -chdir=terraform/live output -raw connect
terraform -chdir=terraform/live output -json helm_values
```

## Mirror the image (P5)

```bash
make mirror PROJECT=your-gcp-project
```

Then in `terraform.tfvars` (picked up by `helm_values`):

```hcl
moodle_image_repository        = "asia-southeast1-docker.pkg.dev/your-gcp-project/moodle/moodle-standard"
binary_authorization_enforce   = true
```

## Defaults you should tighten

- `master_authorized_cidrs` is `0.0.0.0/0` so the first apply works from a
  laptop. Replace with your office / Cloud NAT / IAP CIDR.
- Default storage is **Filestore ZONAL ~1 TiB** (API minimum).
- php-fpm is 5 workers/pod; `sql_max_connections` defaults to 1000.

## Intentionally later

- Helm / Grafana / KEDA in Terraform
- Memorystore Redis
- Filestore scheduled backups
- Secret Manager CSI
- Cloud Armor WAF / OWASP (rate-limit + L7 DDoS only today)
- Uptime SLO on `/readyz` (after the site exists)
- P6 EKS / AWS

## Docs

- [Deploy Moodle](docs/DEPLOY.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Runbook](docs/RUNBOOK.md)
- [Security / ISO mapping](docs/SECURITY.md)
