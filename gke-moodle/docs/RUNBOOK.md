# Runbook

## Infra vs app

`make apply` is **GCP only**. Moodle install: [DEPLOY.md](DEPLOY.md).

Before apply (empty state after a destroy):

```bash
cd gke-moodle
make init
make preflight   # undelete/import Secret Manager ids; fail on leftover names
make apply       # 20–40 min. do not Ctrl+Z
```

Do not delete `ip-alb-moodle` (other stack). `deletion_protection` should stay `true`.

## Switch GCP account / project

Project is only `project_id` in `terraform/live/terraform.tfvars`. Credentials are ADC.

```bash
gcloud auth application-default login   # new account
# edit terraform/live/terraform.tfvars  project_id = "..."
make init                               # new bucket + new live backend; no migrate
```

`gcloud config set project` is optional. Bootstrap state is
`terraform/bootstrap/.states/<project_id>/` so a previous project is not refreshed.

```bash
cd gke-moodle
terraform -chdir=terraform/live output
eval "$(terraform -chdir=terraform/live output -raw connect)"
```

## Observability

GMP is on the cluster (`monitoring_config.managed_prometheus`). Terraform
installs a Cloud SQL dashboard + CPU alert. No in-cluster Grafana yet.

```bash
terraform -chdir=terraform/live output observability
```

```promql
sum(rate(kubernetes_io:container_cpu_core_usage_time{container_name="moodle",namespace_name="moodle"}[5m]))
```

## Connect / site debug (after you Helm-install)

```bash
kubectl -n moodle get deploy,po,svc,gateway,httproute
kubectl -n moodle logs deploy/moodle -c moodle --tail=200
```

1. CrashLoop / ImagePull — Binary Auth or missing image.
2. `cloud-sql-proxy` — `lookup sqladmin.googleapis.com` / UDP `:53` = DNS
   (chart must stay ClusterFirst + `allowAllDns`).
3. `moodle` — install lock, mysqli, Apache `NET_BIND_SERVICE`.
4. Cert: `gcloud certificate-manager certificates describe moodle-cert --location=global`
5. `curl -vk https://$(terraform -chdir=terraform/live output -raw hostname)/readyz`

Stale install lock:

```bash
kubectl -n moodle exec deploy/moodle -c moodle -- rm -rf /var/www/moodledata/.gke-schema.lock
```

## Apply: Filestore zone full

Set `zone` in `terraform.tfvars` to another zone in `node_locations`.

## Backup / restore

- **Database:** Cloud SQL backups + PITR.
- **moodledata / html:** `gcloud filestore backups create`.
- **Secrets:** Secret Manager `moodle-db-password`, `moodle-admin-password`.

## Destroy

Set `deletion_protection = false`, apply that change, then `make destroy`.

Cloud SQL can hold Private Service Access for hours after the instance is
gone. The network module uses `deletion_policy = REMOVE_PEERING`. If an older
state still has `DELETE`:

```bash
gcloud compute networks peerings delete servicenetworking-googleapis-com \
  --network=moodle-vpc --project=YOUR_PROJECT
terraform -chdir=terraform/live state rm module.network.google_service_networking_connection.sql
terraform -chdir=terraform/live destroy
```

Do not `Ctrl+Z` apply/destroy — unlock with
`terraform -chdir=terraform/live force-unlock -force <LOCK_ID>`.
