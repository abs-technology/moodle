# Architecture

Terraform stops at GCP. Workloads are Helm / kubectl ([DEPLOY.md](DEPLOY.md)).

```
Internet
   │
   ├─ Cloud Armor (policy exists; attach via Gateway BackendPolicy when you deploy)
   ▼
Reserved global IP + Certificate Manager  (moodle.<ip>.nip.io)
   │  you create Gateway / HTTPRoute
   ▼
GKE Standard (regional, 1 node min per zone × 3 zones, private nodes, Dataplane V2)
   │
   │  you install charts/moodle
   │
   ├─ Cloud SQL Enterprise Plus  MySQL 8.4
   │    Auth Proxy in the pod → 127.0.0.1:3306  mysqli
   └─ Filestore NFS  html/ + data/  (default)
```

## Why not Bitnami

Bitnami Moodle uses `/bitnami/moodle`, their MariaDB subchart, and different
probes. This image uses `8080`, `/healthz`, `/readyz`, and `MOODLE_*`.

## Why mysqli

`mariadb` is the driver for MariaDB. Cloud SQL here is **MySQL 8.4**.

## Why Auth Proxy on TCP

Unix sockets + MySQL 8.4 `caching_sha2_password` are not reliable on the
Cloud SQL Auth Proxy. The sidecar listens on `127.0.0.1:3306`.

## First boot (when you Helm-install)

`html/` and `data/` are subpaths on one volume.

**filestore (default):** NFS RWX, API minimum ~1 TiB. Init chain:

1. `cloud-sql-proxy`
2. `init-filesystem` — `html/` and `data/` on the share
3. `init-wait-sql` — **mysqli handshake** through the proxy
4. `init-install-gate` — NFS lock on **web** pods only

**pd:** GCE PD RWO, one replica; cron in that pod.

## Hub image vs the chart

Do **not** kubectl-patch the live Deployment. Change `charts/moodle` (or
rebuild the image), then `helm upgrade`.

| Hub 5.2.2-r5 behavior | GKE contract |
|---|---|
| Do not pin `dnsPolicy: None` + `169.254.20.10` | Chart sets `ClusterFirst` |
| NetworkPolicy vs kube-dns ClusterIP | DPv2 matches after DNAT — `allowAllDns` |
| `drop: ALL` + no privilege escalation | Add `NET_BIND_SERVICE` for Apache |
| `/usr/bin/mysql` is MariaDB | Overlay PHP mysqli for MySQL 8.4 |
| `moodle-run.sh` always starts cron | Gate on `MOODLE_CRON_ENABLED` |
| Recursive `setfacl`/`chown` | Skip when `MOODLE_CLUSTER=yes` |

```bash
make -C gke-moodle sync-overlays
```

`make validate` fails if overlays drift.
