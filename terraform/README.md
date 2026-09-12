# Moodle on AWS or GCP

One customer, one directory under `terraform/deployments/`. Name it
`<customer>-aws` or `<customer>-gcp`.

Requires Terraform **1.10+**. After `make new`, edit the generated
`terraform.tfvars` (gitignored). Every optional field is commented there.

| Command | What it does |
|---|---|
| `make deploys` | List every deployment |
| `make new school-b-aws` | Scaffold the directory (once) |
| `make plan school-b-aws` | Preview, change nothing |
| `make apply school-b-aws` | Create or update |
| `make output school-b-aws` | URL, IP, passwords |
| `make ssh school-b-aws` | Shell on the VM |
| `make destroy school-b-aws` | Delete the stack and all Moodle data |

---

## 1 · Authenticate

**AWS** — put an IAM user’s `access_key` and `secret_key` in tfvars, or
`profile = "..."`. The user needs EC2 plus IAM
`CreateRole`, `AttachRolePolicy`, `CreateInstanceProfile`, `PassRole`.

**GCP** — run both commands, then set `project_id` in tfvars:

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project <project_id>
```

A service account is `credentials = "/path/to/sa-key.json"`.

---

## 2 · Ship on nip.io

```bash
make new school-b-aws
```

Fill `terraform/deployments/school-b-aws/terraform.tfvars`:

| | AWS | GCP |
|---|---|---|
| `name` | Set from the directory. Must be unique in the account. | Unique in the project. |
| Auth | `access_key` + `secret_key`, or `profile` | `project_id` |
| Place | `region` — `ap-southeast-1` | `region` + `zone` — `asia-southeast1` / `asia-southeast1-a` |
| `acme_email` | Real public address. Let’s Encrypt rejects `.test` and `.local`. | Same |
| `ssh_allowed_cidrs` | `["0.0.0.0/0"]` → SSH with `break-glass.pem` | Same |

Leave `moodle_domain` empty. Changing it later does not move a live site —
use [step 3](#3--cut-over-the-domain).

```bash
make apply school-b-aws
make output school-b-aws
```

In 4–6 minutes open `https://moodle.<public_ip>.nip.io`.

| | Value |
|---|---|
| Moodle login | `moodle_admin_user` (default `absi_admin`) |
| Moodle password | `moodle_admin_password` |
| SSH user | `admin` |
| Public IP | `public_ip` — static, keep it for DNS |

Watch the first boot from the deployment directory:

```bash
eval "$(terraform output -raw bootstrap_log_command)"
curl -sI "$(terraform output -raw site_url)"         # 200
curl -s  "$(terraform output -raw site_url)/readyz"  # ready
```

---

## 3 · Cut over the domain

The nip.io URL stays up until the last command.

1. Point the domain’s **A** record at `public_ip`.
2. Copy the certificate. Leaf first, no passphrase on the key.

```bash
cd terraform/deployments/school-b-aws
scp -i break-glass.pem fullchain.pem privkey.pem admin@<IP>:/tmp/
```

3. Cut over. Logged-in users are signed out; nip.io stops.

```bash
make ssh school-b-aws
cd /opt/moodle
sudo ./change-domain.sh --domain lms.example.com \
    --cert /tmp/fullchain.pem --key /tmp/privkey.pem
```

`--letsencrypt` replaces `--cert` / `--key` if you want Let’s Encrypt on the
new name.

Then set `moodle_domain = "lms.example.com"` in tfvars so `make deploys`
shows the real host.

Flags and recovery: [examples/traefik/README.md](../examples/traefik/README.md).

---

## Day to day

```bash
make ssh school-b-aws
```

Uses `break-glass.pem` when it exists. AWS Session Manager without it needs:

```bash
brew install --cask session-manager-plugin
```

Roll a new compose file on the running VM (Terraform will not replace the
instance for compose or AMI edits):

```bash
make ssh school-b-aws
cd /opt/moodle && docker compose up -d
```

`make destroy` deletes the disk. Back up `/opt/moodle/data` first if you
need it.

---

## Optional

| Need | Setting |
|---|---|
| Domain on first boot | Set `moodle_domain`, apply, then point DNS at `public_ip`. Traefik retries ACME until the record exists. |
| ACME staging | `acme_staging = true` — certificates are not trusted. |
| Custom state bucket | `TF_STATE_BUCKET=...` on first apply. Skip creation with `TF_SKIP_BUCKET=1`. Default: `absi-moodle-tfstate-<account>` or `absi-moodle-tfstate-<project_id>` in the same account as the credentials. |
| Extra independent sites | Another directory: `school-b-prod-aws`, `school-b-staging-aws`. Shared data across VMs: [LOAD-BALANCING.md](../docs/LOAD-BALANCING.md). |

**AWS Local Zone** — opt in first, then a non-burstable type (Hanoi has no `t3`):

```bash
aws ec2 modify-availability-zone-group \
  --group-name ap-southeast-1-han-1 --opt-in-status opted-in
```

```hcl
availability_zone = "ap-southeast-1-han-1a"
instance_type     = "m7i.large"
```
