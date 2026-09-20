# Moodle on AWS or GCP

One customer = one Moodle site = one directory under `terraform/deployments/`.
Each directory has its own credentials, its own VM, and its own Terraform state.
A second customer is a second directory — never edit the first one to “reuse” it.

Requires Terraform **1.10+**. Run every `make` command from the **repo root**.

One command shape for every frontend. AWS examples below; for GCP swap `aws` → `gcp`.

```bash
make create  aws-traefik school-b
make plan    aws-traefik school-b
make apply   aws-traefik school-b
make destroy aws-traefik school-b
make ssh     aws-traefik school-b
make output  aws-traefik school-b
make tf-list
```

| Track | Template | Marker | First boot |
|---|---|---|---|
| `aws-traefik` / `gcp-traefik` | `templates/aws-traefik/` or `gcp-traefik/` | `frontend.traefik` | Traefik + Let's Encrypt on `moodle.<ip>.nip.io` |
| `aws-ip` / `gcp-ip` | `templates/aws-ip/` or `gcp-ip/` | `frontend.ip` | Moodle on `http://<public-ip>` |
| `aws-alb` | `templates/aws-alb/` | `frontend.alb` | Global Accelerator (anycast) + ALB → Moodle `:8080` |
| `aws-marketplace` | `templates/aws-marketplace/` | `frontend.marketplace` | us-east-1 builder (aws-ip stack, unencrypted root) → AMI |
| `gcp-alb` | `templates/gcp-alb/` | `frontend.alb` | GCP Global ALB + Certificate Manager |

`make create aws-traefik school-b` writes
`terraform/deployments/school-b-aws/` so the same app name can exist on GCP
(`school-b-gcp`). Later commands accept `school-b` or `school-b-aws`.

`make tf-list` prints `DEPLOYMENT  TRACK  IP  DOMAIN` (`TRACK` is `aws-traefik`,
`gcp-alb`, …). `make deploys` is an alias.

---

## Layout

You only create and edit files under `deployments/`. Modules and templates stay
shared.

```
terraform/
├── modules/                 shared — do not copy per customer
│   ├── moodle-aws/
│   ├── moodle-gcp/
│   └── bootstrap/
├── templates/               aws-traefik/ gcp-traefik/ aws-ip/ gcp-ip/ aws-alb/ aws-marketplace/ gcp-alb/
└── deployments/
    ├── horizonschool-aws/   customer A
    └── school-b-gcp/        customer B
```

`make create aws-traefik school-b` copies `templates/aws-traefik/` into
`terraform/deployments/school-b-aws/` and writes:

| File | Who writes it | You edit? |
|---|---|---|
| `terraform.tfvars` | `make create` (from the example) | **Yes — this is the only file you fill in** |
| `main.tf` | `make create` | No |
| `variables.tf` | `make create` | No |
| `outputs.tf` | `make create` | No |
| `frontend.traefik` | `make create` | No — track marker |
| `backend.tf` | first `make apply` | No |
| `break-glass.pem` | first `make apply` (if SSH CIDRs are set) | No — private key |
| `.terraform.lock.hcl` | first `make apply` | No |

`terraform.tfvars` and `break-glass.pem` are gitignored. Do not commit them.

---

## 1 · Authenticate

Do this once on the machine you run Terraform from.

**AWS** — an IAM user with EC2 plus
`CreateRole`, `AttachRolePolicy`, `CreateInstanceProfile`, `PassRole`,
and DLM (`dlm:*`, `iam:PassRole` for the `*-dlm` role).
`aws-alb` also needs Elastic Load Balancing, Global Accelerator, ACM, and
NAT Gateway. `aws-marketplace` uses the same EC2/IAM/DLM rights as `aws-ip`
plus `ec2:CreateSnapshot`, `ec2:RegisterImage`,
`ec2:GetEbsEncryptionByDefault`, and SSM `SendCommand` /
`GetCommandInvocation` (to delete `authorized_keys` before the snapshot). You will paste the key into tfvars in
step 2 (or use `profile = "..."`).

**GCP** — then you will set `project_id` in tfvars:

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project <project_id>
```

A service account is `credentials = "/path/to/sa-key.json"` in tfvars instead.

---

## 2 · Create a new server

Example: a new AWS site named `school-b`. GCP is the same track with `gcp-`.

### 2.1 Scaffold

```bash
make create aws-traefik school-b   # Traefik + Let's Encrypt on first boot
make create aws-ip school-b        # Moodle only — open http://<public-ip>
make create aws-alb school-b       # Global Accelerator + ALB (no public IP on the VM)
make create aws-marketplace ami-builder  # us-east-1 unencrypted AMI (not a customer site)
make create gcp-alb school-b       # GCP Global ALB
```

That only creates files. No VM yet. `aws-ip` is the same afterwards except you
run `make apply aws-ip school-b` / `make ssh aws-ip school-b`, and `site_url`
is `http://<ip>` until you SSH in and run `change-domain.sh --nip` or
`--cert` / `--letsencrypt`.

### 2.2 Edit `terraform.tfvars`

Open **this file only**:

`terraform/deployments/school-b-aws/terraform.tfvars`

Replace the placeholders. Leave every `#` line alone unless you need that
option.

**AWS — required lines**

```hcl
name       = "school-b-aws"          # already set; unique in the AWS account
acme_email = "admin@school-b.com"    # real public email, not .test / .local
access_key = "AKIA..."
secret_key = "..."
region     = "ap-southeast-1"
os         = "debian-13"             # debian-12 or ubuntu-24.04; first boot only
ssh_allowed_cidrs = ["0.0.0.0/0"]    # writes break-glass.pem; needed for make ssh
```

**GCP — required lines** (`make create gcp-traefik school-b`)

```hcl
name       = "school-b-gcp"          # already set; unique in the GCP project
project_id = "their-gcp-project"
acme_email = "admin@school-b.com"
region     = "asia-southeast1"
zone       = "asia-southeast1-a"
os         = "debian-13"             # debian-12 or ubuntu-24.04; first boot only
ssh_allowed_cidrs = ["0.0.0.0/0"]
```

| Leave empty / commented | Why |
|---|---|
| `moodle_domain` | First boot uses `moodle.<ip>.nip.io`. Do not set this to “move” a live site. |
| `acme_staging` | Only for repeated test applies (certs are not trusted). |
| `availability_zone` / `instance_type` | AWS Local Zone only — see Optional. |
| `os` | Default `debian-13`. Set before the first apply. A later change does not replace the VM. |

Do not copy another customer’s `terraform.tfvars`. Keys and `name` must be this
site’s.

### 2.3 Create the VM

```bash
make apply aws-traefik school-b   # or: make apply aws-ip school-b
```

Read the plan, type `yes`. First apply also creates a **per-deployment** state
bucket in the VM region (`absi-moodle-tfstate-<name>`, or `tf_state_bucket`
in tfvars), writes `backend.tf`, and turns on a
weekly snapshot at Sunday 22:00 Asia/Ho_Chi_Minh (keep 24 weeks). The VM
clock is the same timezone. Wait 4–6
minutes.

```bash
make output aws-traefik school-b
```

| Output | Use |
|---|---|
| `site_url` | Open in the browser — Traefik: `https://moodle.<ip>.nip.io`; IP-direct: `http://<ip>`; ALB: `https://moodle.<anycast-or-global-ip>.nip.io` |
| `moodle_admin_user` | Moodle login (default `absi_admin`) |
| `moodle_admin_password` | Moodle password |
| `public_ip` | Write down — DNS in step 3 uses this. It does not change. |
| SSH user | Always `admin` (not the Moodle user) |

If the site is not up yet, from `terraform/deployments/school-b-aws/`:

```bash
eval "$(terraform output -raw bootstrap_log_command)"
curl -sI "$(terraform output -raw site_url)"         # 200
curl -s  "$(terraform output -raw site_url)/readyz"  # ready
```

Hand the nip.io URL to the customer. They can install courses now.

**aws-alb / gcp-alb** — the VM has no public IP. `public_ip` is the anycast
(global) address. `make ssh aws-alb <name>` is Session Manager (`brew install
--cask session-manager-plugin`). `make ssh gcp-alb` is IAP.

AWS cannot get an ACM-issued cert for `nip.io` (ACM is DNS-01 only). The
site starts on a placeholder, then the VM runs Let's Encrypt HTTP-01 and
imports the trusted cert onto the same ACM ARN (timer `absi-alb-acme`,
log `/var/log/absi-alb-acme.log`). Wait a few minutes after `/readyz` is
up. Staging: `acme_staging = true`. A cert you already own is still
`moodle_domain` plus `route53_zone_id` or `acm_certificate_arn` before apply.
GCP Certificate Manager issues nip.io on its own.
`change-domain.sh` does not apply to ALB sites.

**aws-marketplace** — builder only, not a customer site. Same first boot as
`aws-ip` (`http://<public-ip>`), in **us-east-1**, root volume **unencrypted**
(Marketplace rejects encrypted snapshots). Instance type defaults to
`c7i.large`. After `/readyz` is 200, set `create_ami = true` and apply again:
Terraform removes `authorized_keys` under `/root/.ssh` and `/home/*/.ssh`
(SSM), stops the VM, snapshots the root volume, and registers an AMI with
`imds_support = v2.0`. [AMI build guide](https://docs.aws.amazon.com/marketplace/latest/userguide/best-practices-for-building-your-amis.html).
If plan fails on EBS default encryption, turn that off in us-east-1 first.
The AMI and its snapshot are shared with the Marketplace ingestion account
`679593333241`. AccessARN is role `abs-ami-marketplace-role` — use output
`marketplace_access_arn` (the full `arn:aws:iam::…:role/abs-ami-marketplace-role`)
in Seller Portal. Set `manage_marketplace_role = true` only if that role does
not already exist in the account.

---

## 3 · IP-direct → nip.io + Let's Encrypt

On the VM. Terraform does not do this. `ACME_EMAIL=admin@example.com` is
rejected; the script asks for a real address or takes `--email`.

```bash
make ssh aws-ip school-b
cd /opt/moodle
sudo ./change-domain.sh --nip
# or: sudo ./change-domain.sh --nip --name moodle --email you@school.com
```

Type only the **site name** (e.g. `moodle`). The host is
`<name>.<public-ip>.nip.io`. Then **one line** in
`terraform/deployments/school-b-aws/terraform.tfvars` — do not apply:

```hcl
moodle_domain = "moodle.<ip>.nip.io"
```

Site is `https://moodle.<ip>.nip.io`. A VM created before this `--email` prompt
needs the current `examples/traefik/change-domain.sh` copied to
`/opt/moodle/change-domain.sh` first.

---

## 4 · Move that server to the real domain

Still the same directory. Terraform does not move the site — you run a script
on the VM.

1. In DNS, point the domain’s **A** record at `public_ip` from step 2.
   nip.io keeps working until the last command.
2. Copy the certificate (leaf first, no passphrase on the key):

```bash
cd terraform/deployments/school-b-aws
scp -i break-glass.pem fullchain.pem privkey.pem admin@<IP>:/tmp/   # Ubuntu: ubuntu@
```

3. Cut over (everyone is signed out; nip.io stops):

```bash
make ssh aws-traefik school-b  # IP-direct: make ssh aws-ip school-b
cd /opt/moodle
sudo ./change-domain.sh --domain lms.example.com \
    --cert /tmp/fullchain.pem --key /tmp/privkey.pem
```

`--letsencrypt` instead of `--cert` / `--key` if you want Let’s Encrypt on the
new name (`--email` if `.env` still has `admin@example.com`). IP-direct → nip.io
is section 3.

4. **Update this one line** in
   `terraform/deployments/school-b-aws/terraform.tfvars` so `make tf-list`
   shows the real host:

```hcl
moodle_domain = "lms.example.com"
```

Do not run `make apply` just for that line. Flags and recovery:
[examples/traefik/README.md](../examples/traefik/README.md).

---

## What to change later — which file

| You want | Where | How |
|---|---|---|
| New customer / new independent site | New directory | `make create aws-traefik other` (or `aws-ip` / `aws-alb` / `gcp-alb`) and start at step 2. Do not reuse this folder. |
| Staging + production for one school | Two directories | `make create aws-traefik school-b-prod` and `school-b-staging` |
| Region, instance size, SSH CIDRs, ACME email | `terraform.tfvars` | Edit, then `make plan aws-traefik school-b` / `make apply aws-traefik school-b` |
| Guest OS | `os` in tfvars | `debian-13` (default), `debian-12`, or `ubuntu-24.04`. Only before the first apply. |
| Timezone / weekly snapshots | `terraform.tfvars` | Default `Asia/Ho_Chi_Minh`, Sunday 22:00, 24 copies. `snapshot_weekly = false` or `snapshot_retain_weeks = 12`, then apply |
| Allow deleting the VM | `terraform.tfvars` | Default on. Set `vm_deletion_protection = false`, `make apply <track> <name>`, then `make destroy <track> <name>` |
| Moodle admin **username** | `moodle_admin_user` in tfvars | Only **before** the first apply |
| Moodle / MariaDB **passwords** | — | Generated. Read with `make output <track> <name>`. Do not put them in tfvars. |
| IP-direct → nip.io + Let's Encrypt | VM + one tfvars line | Section 3 (`--nip` / `--email`), then set `moodle_domain` |
| Real domain after the site has data | VM + one tfvars line | Section 4 (`change-domain.sh`), then set `moodle_domain` |
| New `docker-compose.yml` or image tag | The VM | `make ssh <track> <name>` then `cd /opt/moodle && docker compose up -d`. `make apply` will not replace the VM for compose/AMI edits. |
| Shared Moodle data across several VMs | — | Not this layout. See [LOAD-BALANCING.md](../docs/LOAD-BALANCING.md). |

There is no default customer. Every command takes `<track> <name>`.

---

## Day to day

```bash
make ssh aws-traefik school-b
```

Uses `break-glass.pem` when it exists (Traefik / IP-direct). `aws-alb` is
always Session Manager:

```bash
brew install --cask session-manager-plugin
```

`make destroy` will fail while protection is on (default). First set
`vm_deletion_protection = false` in that site’s tfvars, then
`make apply <track> <name>`, then `make destroy <track> <name>`. That also
unlocks Delete in the AWS/GCP console (`aws-alb` uses the same flag on the ALB). Back up `/opt/moodle/data` first if you
need it.

---

## Optional

| Need | What to edit |
|---|---|
| Domain on first boot (empty site) | Set `moodle_domain` in tfvars **before** apply, apply, then point DNS at `public_ip`. |
| ACME staging | `acme_staging = true` in tfvars |
| Custom state bucket name | `tf_state_bucket = "..."` in tfvars (first plan/apply). Or `TF_STATE_BUCKET=...`. Skip creation: `TF_SKIP_BUCKET=1`. Default: `absi-moodle-tfstate-<deployment>` — no project/account in the name. Existing `backend.tf` is never rewritten. |
| Turn off weekly snapshots | `snapshot_weekly = false` in tfvars, then apply |
| New IP-direct site | New directory | `make create aws-ip school-b` (or `gcp-ip`), fill tfvars, `make apply aws-ip school-b`. Site is `http://<public-ip>`. Then `make ssh aws-ip school-b` and `sudo ./change-domain.sh --nip`. |
| New ALB site (GCP) | New directory | `make create gcp-alb school-b`, fill tfvars, `make apply gcp-alb school-b`. ALB → NEG → Moodle `:8080`, no Traefik. |
| New ALB site (AWS) | New directory | `make create aws-alb school-b`, fill tfvars, `make apply aws-alb school-b`. Anycast → ALB → Moodle `:8080`, no Traefik, VM has no public IP. `make ssh` is Session Manager. |
| Marketplace AMI | New directory | `make create aws-marketplace ami-builder`. us-east-1, `c7i.large`, unencrypted root. Apply, wait for `/readyz`, set `create_ami = true`, apply again. AMI is shared with `679593333241`. |

**AWS Local Zone** — opt in, then uncomment in tfvars (Hanoi has no `t3`):

```bash
aws ec2 modify-availability-zone-group \
  --group-name ap-southeast-1-han-1 --opt-in-status opted-in
```

```hcl
availability_zone = "ap-southeast-1-han-1a"
instance_type     = "m7i.large"
```
