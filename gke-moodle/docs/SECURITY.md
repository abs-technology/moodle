# Security / ISO-oriented controls

This is a control mapping, not a certification.

| ISO 27001-ish area | Implementation |
|---|---|
| A.8 assets | Separate GCP project recommended; labels `app=moodle` |
| A.9 access | Workload Identity (no JSON keys); Moodle GSA is Cloud SQL client + metricWriter |
| A.10 crypto | TLS at the Global ALB (after you attach Gateway + certmap); Cloud SQL `ENCRYPTED_ONLY`; optional CMEK |
| A.12 ops | Cloud Audit / GKE / SQL insights; Managed Prometheus; SQL CPU alert |
| A.13 network | Private GKE nodes, Cloud NAT, private SQL, Cloud Armor policy, Filestore NFS from node tags |
| A.14 supply chain | Artifact Registry, optional Binary Authorization enforce |
| A.16 incident | SQL CPU alert + optional email channel |
| A.17 continuity | SQL REGIONAL HA + PITR; Filestore snapshots; `deletion_protection` |

NetworkPolicy / `/readyz` SLO apply when you install the Helm chart.

## Hardening checklist (P5)

- [ ] `master_authorized_cidrs` is not `0.0.0.0/0`
- [ ] Image mirrored; `binary_authorization_enforce = true`
- [ ] `notification_email` set
- [ ] Cloud Armor rate limit reviewed (default 300 req/min/IP)
- [ ] Secret Manager not committed; Kubernetes secret created at deploy time
- [ ] Restore drill (SQL clone + Filestore snapshot) documented with a date
- [ ] `enable_cmek = true` if the customer requires customer-managed keys
- [ ] Org policies (public IP, SA key creation) at folder/org — outside this stack

## What we deliberately do not do

- IAP in front of Moodle (learners need a public LMS).
- In-cluster MariaDB / Bitnami.
- Autopilot (requested Standard).
- Sharing state or modules with `terraform/modules/moodle-*`.
- Terraform-managed Helm until the manual install is signed off.
