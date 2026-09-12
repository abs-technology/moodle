# Moodle on AWS or GCP

One customer = one Moodle site = one directory under `terraform/deployments/`.
Each directory has its own credentials, its own VM, and its own Terraform state.
A second customer is a second directory — never edit the first one to “reuse” it.

Name the directory `<customer>-aws` or `<customer>-gcp` so `make` picks the cloud.

Requires Terraform **1.10+**. Run every `make` command from the **repo root**.

| Command | What it does |
|---|---|
| `make deploys` | List deployments, IPs, and domains |
| `make new school-b-aws` | Create the directory (once per site) |
| `make plan school-b-aws` | Preview, change nothing |
| `make apply school-b-aws` | Create or update that site only |
| `make output school-b-aws` | URL, IP, passwords |
| `make ssh school-b-aws` | Shell on that VM |
| `make destroy school-b-aws` | Delete that site and all its Moodle data |

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
├── templates/               used only by `make new`
└── deployments/
    ├── horizonschool-aws/   customer A
    └── school-b-gcp/        customer B
```

`make new school-b-aws` copies the AWS template into
`terraform/deployments/school-b-aws/` and writes:

| File | Who writes it | You edit? |
|---|---|---|
| `terraform.tfvars` | `make new` (from the example) | **Yes — this is the only file you fill in** |
| `main.tf` | `make new` | No |
| `variables.tf` | `make new` | No |
| `outputs.tf` | `make new` | No |
| `backend.tf` | first `make apply` | No |
| `break-glass.pem` | first `make apply` (if SSH CIDRs are set) | No — private key |
| `.terraform.lock.hcl` | first `make apply` | No |

`terraform.tfvars` and `break-glass.pem` are gitignored. Do not commit them.

---

## 1 · Authenticate

Do this once on the machine you run Terraform from.

**AWS** — an IAM user with EC2 plus
`CreateRole`, `AttachRolePolicy`, `CreateInstanceProfile`, `PassRole`.
You will paste the key into tfvars in step 2 (or use `profile = "..."`).

**GCP** — then you will set `project_id` in tfvars:

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project <project_id>
```

A service account is `credentials = "/path/to/sa-key.json"` in tfvars instead.

---

## 2 · Create a new server

Example: a new AWS site named `school-b`. For GCP, use `school-b-gcp` and the
GCP column below.

### 2.1 Scaffold

```bash
make new school-b-aws
```

That only creates files. No VM yet.

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
ssh_allowed_cidrs = ["0.0.0.0/0"]    # writes break-glass.pem; needed for make ssh
```

**GCP — required lines** (`make new school-b-gcp`)

```hcl
name       = "school-b-gcp"          # already set; unique in the GCP project
project_id = "their-gcp-project"
acme_email = "admin@school-b.com"
region     = "asia-southeast1"
zone       = "asia-southeast1-a"
ssh_allowed_cidrs = ["0.0.0.0/0"]
```

| Leave empty / commented | Why |
|---|---|
| `moodle_domain` | First boot uses `moodle.<ip>.nip.io`. Do not set this to “move” a live site. |
| `acme_staging` | Only for repeated test applies (certs are not trusted). |
| `availability_zone` / `instance_type` | AWS Local Zone only — see Optional. |

Do not copy another customer’s `terraform.tfvars`. Keys and `name` must be this
site’s.

### 2.3 Create the VM

```bash
make apply school-b-aws
```

Read the plan, type `yes`. First apply also creates the state bucket in **this
customer’s** AWS account / GCP project and writes `backend.tf`. Wait 4–6
minutes.

```bash
make output school-b-aws
```

| Output | Use |
|---|---|
| `site_url` | Open in the browser — `https://moodle.<ip>.nip.io` |
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

---

## 3 · Move that server to the real domain

Still the same directory. Terraform does not move the site — you run a script
on the VM.

1. In DNS, point the domain’s **A** record at `public_ip` from step 2.
   nip.io keeps working until the last command.
2. Copy the certificate (leaf first, no passphrase on the key):

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

`--letsencrypt` instead of `--cert` / `--key` if you want Let’s Encrypt on the
new name.

4. **Update this one line** in
   `terraform/deployments/school-b-aws/terraform.tfvars` so `make deploys`
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
| New customer / new independent site | New directory | `make new other-aws` and start at step 2. Do not reuse this folder. |
| Staging + production for one school | Two directories | `school-b-prod-aws` and `school-b-staging-aws` |
| Region, instance size, SSH CIDRs, ACME email | `terraform.tfvars` | Edit, then `make plan` / `make apply` |
| Moodle admin **username** | `moodle_admin_user` in tfvars | Only **before** the first apply |
| Moodle / MariaDB **passwords** | — | Generated. Read with `make output`. Do not put them in tfvars. |
| Real domain after the site has data | VM + one tfvars line | Step 3 (`change-domain.sh`), then set `moodle_domain` |
| New `docker-compose.yml` or image tag | The VM | `make ssh …` then `cd /opt/moodle && docker compose up -d`. `make apply` will not replace the VM for compose/AMI edits. |
| Shared Moodle data across several VMs | — | Not this layout. See [LOAD-BALANCING.md](../docs/LOAD-BALANCING.md). |

`make apply` / `make destroy` always take the directory name. There is no
default customer.

---

## Day to day

```bash
make ssh school-b-aws
```

Uses `break-glass.pem` when it exists. AWS Session Manager without it:

```bash
brew install --cask session-manager-plugin
```

`make destroy school-b-aws` deletes the disk. Back up `/opt/moodle/data` first
if you need it.

---

## Optional

| Need | What to edit |
|---|---|
| Domain on first boot (empty site) | Set `moodle_domain` in tfvars **before** apply, apply, then point DNS at `public_ip`. |
| ACME staging | `acme_staging = true` in tfvars |
| Custom state bucket name | `TF_STATE_BUCKET=... make apply school-b-aws` on the first apply. Skip creation: `TF_SKIP_BUCKET=1`. Default: `absi-moodle-tfstate-<account>` or `absi-moodle-tfstate-<project_id>` in the same account as the keys. |

**AWS Local Zone** — opt in, then uncomment in tfvars (Hanoi has no `t3`):

```bash
aws ec2 modify-availability-zone-group \
  --group-name ap-southeast-1-han-1 --opt-in-status opted-in
```

```hcl
availability_zone = "ap-southeast-1-han-1a"
instance_type     = "m7i.large"
```
