# Deploy Moodle on AWS or GCP

One customer = one directory under `terraform/deployments/`. Name it `<customer>-aws`
or `<customer>-gcp` so `make` knows which cloud.

```bash
make deploys              # list deployments
make new school-b-aws     # scaffold (once)
make plan school-b-aws    # preview
make apply school-b-aws   # create or update
make output school-b-aws  # URL, IP, passwords
make ssh school-b-aws     # shell on the VM
make destroy school-b-aws # delete the stack and all Moodle data
```

Needs Terraform >= 1.10. Fill `terraform.tfvars` after `make new` — that file is
gitignored. Comments in the generated file list every optional setting.

## 1. Authenticate

**AWS** — IAM user key in tfvars (`access_key` / `secret_key`), or `profile = "..."`.
Needs EC2 + IAM (`CreateRole`, `AttachRolePolicy`, `CreateInstanceProfile`, `PassRole`).

**GCP** — both commands, then set `project_id` in tfvars:

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project <project_id>
```

Or a service account: `credentials = "/path/to/sa-key.json"`.

## 2. Create the site (nip.io, no DNS)

```bash
make new school-b-aws
```

Edit `terraform/deployments/school-b-aws/terraform.tfvars`:

| Field | AWS | GCP |
|---|---|---|
| `name` | already set from the directory name — keep it unique in the account/project | same |
| credentials | `access_key` + `secret_key` (or `profile`) | `project_id` |
| `region` | e.g. `ap-southeast-1` | e.g. `asia-southeast1` + `zone` |
| `acme_email` | real public email (Let's Encrypt rejects `.test` / `.local`) | same |
| `ssh_allowed_cidrs` | `["0.0.0.0/0"]` for SSH via `break-glass.pem` | same |

```bash
make apply school-b-aws
make output school-b-aws
```

Wait 4–6 minutes, then open `https://moodle.<public_ip>.nip.io`. Login is
`moodle_admin_user` (default `absi_admin`) and `moodle_admin_password`. SSH user is
`admin`. The IP is static — keep it for the next phase.

First boot log, from the deployment directory:

```bash
eval "$(terraform output -raw bootstrap_log_command)"
curl -sI "$(terraform output -raw site_url)"         # 200
curl -s  "$(terraform output -raw site_url)/readyz"  # ready
```

Leave `moodle_domain` empty. Do not set it in tfvars to “move” a live site — that does
not rewrite Moodle. Use step 3.

## 3. Move to the real domain

1. Point the A record at `public_ip` from step 2. nip.io keeps working until you cut over.
2. Copy the cert (leaf first, no passphrase on the key):

```bash
cd terraform/deployments/school-b-aws
scp -i break-glass.pem fullchain.pem privkey.pem admin@<IP>:/tmp/
```

3. Cut over (everyone is signed out; nip.io stops):

```bash
make ssh school-b-aws
cd /opt/moodle
sudo ./change-domain.sh --domain lms.example.com \
    --cert /tmp/fullchain.pem --key /tmp/privkey.pem
```

Use `--letsencrypt` instead of `--cert` / `--key` if you want Let's Encrypt on the new
name. Then set `moodle_domain = "lms.example.com"` in tfvars so `make deploys` shows the
real host. Flags and recovery: [../examples/traefik/README.md](../examples/traefik/README.md).

## Day-to-day

```bash
make ssh school-b-aws                          # prefers break-glass.pem
# AWS without break-glass needs: brew install --cask session-manager-plugin
```

Update compose on a running VM (Terraform will not replace the instance for compose/AMI
changes):

```bash
make ssh school-b-aws
cd /opt/moodle && docker compose up -d
```

Destroy deletes the disk. Back up `/opt/moodle/data` first if you need it.

## Optional

**Own domain from the first apply** — set `moodle_domain`, apply, then point DNS at
`public_ip`. Traefik retries ACME until the record exists.

**Let's Encrypt staging** — `acme_staging = true` (certificates are not trusted).

**State bucket** — created on first `make apply` in the same AWS account / GCP project as
the credentials (`absi-moodle-tfstate-<account>` or `absi-moodle-tfstate-<project_id>`).
Override with `TF_STATE_BUCKET=...` or skip creation with `TF_SKIP_BUCKET=1`.

**Several independent sites for one customer** — several directories
(`school-b-prod-aws`, `school-b-staging-aws`). Shared data across VMs is
[../docs/LOAD-BALANCING.md](../docs/LOAD-BALANCING.md).

**AWS Local Zone** — opt in first, then set a non-burstable type (Hanoi has no `t3`):

```bash
aws ec2 modify-availability-zone-group \
  --group-name ap-southeast-1-han-1 --opt-in-status opted-in
```

```hcl
availability_zone = "ap-southeast-1-han-1a"
instance_type     = "m7i.large"
```
