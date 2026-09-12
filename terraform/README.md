# Moodle on GCP / AWS with Terraform

Each deployment creates a fresh VPC and one Debian 13 amd64 VM running Moodle behind
Traefik.

Nothing is cloned or built on the VM. Terraform reads
`examples/traefik/docker-compose.yml`, embeds it in instance metadata with a generated
`.env`, and the bootstrap script installs Docker from the official apt repo, writes both
files to `/opt/moodle`, and runs `docker compose up -d` to pull
`abstechnology/moodle-standard:5.2.2-r5`.

## One customer, one directory

Every Moodle site is a directory under `terraform/deployments/` with its own state and
credentials. This is the safety boundary that matters most: no `apply` or `destroy` can
reach another customer's stack, even if you mistype.

```
terraform/
├── modules/
│   ├── moodle-aws/       AWS infrastructure, shared by every customer
│   ├── moodle-gcp/       GCP infrastructure
│   └── bootstrap/        VM install script, shared by both clouds
├── templates/            scaffolding for a new deployment
└── deployments/
    └── horizonschool-aws/    main.tf, variables.tf, outputs.tf, backend.tf, terraform.tfvars
```

The customer name goes straight after the verb — no variables, no `cd`, run from the repo
root:

```bash
make deploys                   # who is running where
make new school-b-gcp          # create a customer, once in its lifetime
make plan school-b-gcp         # preview, touches nothing
make apply school-b-gcp        # build or update
make output school-b-gcp       # every output, passwords included
make ssh school-b-gcp          # get on the VM
make destroy school-b-gcp      # delete, and lose that customer's data
```

The `-aws` or `-gcp` suffix picks the cloud, so `make new` never asks; add `CLOUD=aws` or
`CLOUD=gcp` for a name outside that convention. `make new` copies the template,
substitutes the name, and writes a `terraform.tfvars` to fill in.

Mistyping a name fails with the list of names that do exist. No command has a default
deployment, so `make destroy` cannot run against a customer you did not name.

`name` is required and has no default: IAM roles and key pairs are account-wide on AWS and
VPC and firewall names are unique per project on GCP, so two customers sharing a `name`
collide on the second apply.

One customer with several independent sites gets several deployments —
`school-b-prod-aws`, `school-b-staging-aws`. Several VMs serving **one** Moodle site is a
different problem needing shared `moodledata` and sessions in the database; see
[../docs/LOAD-BALANCING.md](../docs/LOAD-BALANCING.md).

## State lives in the customer's own account

State goes to `absi-moodle-tfstate-<account>` (AWS) or
`absi-moodle-tfstate-<project_id>` (GCP), encrypted and versioned, in the same account the
deployment's credentials point at — so infrastructure and the state describing it never
drift apart.

This took a bug to get right. A Terraform `backend` block **cannot use variables**, so it
cannot read `var.access_key`. Left alone it falls back to whatever default profile the
machine has, and a customer's state — carrying their Moodle and MariaDB passwords in
plaintext — lands in an unrelated account whose loss would cost the ability to destroy any
stack.

Two things prevent that. `backend.tf` is **generated** on the first `make apply`, once
tfvars has credentials, so the bucket name comes from `sts get-caller-identity` under those
exact credentials. And `make` exports `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (or
`GOOGLE_APPLICATION_CREDENTIALS`) from tfvars before every Terraform command, the only way
to get credentials into a backend.

An existing `backend.tf` is **never overwritten**: repoint Terraform silently and it sees
empty state and offers to rebuild everything. Use `TF_STATE_BUCKET` to name the bucket
yourself, or `TF_SKIP_BUCKET=1` when someone else manages it.

## Prerequisites

Terraform >= 1.10, since `use_lockfile` replaces the old DynamoDB lock table.
`acme_email` is required and must use a real public TLD — Let's Encrypt rejects `.test`,
`.local` and other reserved suffixes.

**AWS.** An IAM user's key and secret in tfvars, or `profile = "..."` instead. Empty
variables are ignored, and provider configuration never reaches state, so keys stay out of
`terraform.tfstate`. The user needs EC2 (VPC, subnet, internet gateway, route table,
security group, network interface, Elastic IP, instance) and IAM (`CreateRole`,
`AttachRolePolicy`, `CreateInstanceProfile`, `PassRole`) for the SSM instance profile. Use
an IAM user, not root keys: root cannot be scoped or revoked piecemeal.

**GCP.** `project_id` plus **both** auth commands:

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project <project_id>
```

The CLI and Terraform read separate credential sets. Switch accounts with the first
command only and `gcloud projects list` reports the new account while `terraform apply`
still gets 403 as the old identity. A service account avoids the problem:
`credentials = "/path/to/sa-key.json"`, needing `roles/compute.admin`, plus
`roles/serviceusage.serviceUsageAdmin` if `enable_apis = true` and
`roles/iap.tunnelResourceAccessor` with `roles/compute.osLogin` for the IAP route.

## Deploy now, move to a real domain later

Seven steps, two phases: ship on nip.io so the customer can start immediately, then move
to their domain and certificate once bought.

### Phase 1 — on nip.io

**1.** `make new school-b-aws`, then edit
`terraform/deployments/school-b-aws/terraform.tfvars`: `access_key`, `secret_key`,
`region`, `acme_email`, `ssh_allowed_cidrs = ["0.0.0.0/0"]`. On GCP set `project_id`
instead of the key pair. `name` is already filled in.

**2.** `make apply school-b-aws`, read the plan, type `yes`. Four to six minutes later the
site answers over real HTTPS at `https://moodle.<ip>.nip.io` with a Let's Encrypt
certificate, and no DNS work was needed.

**3.** `make output school-b-aws` prints `moodle_admin_user` (`absi_admin` by default),
`moodle_admin_password` and `public_ip`. Write the IP down. Rename the admin through
`moodle_admin_user` before applying; the password is always generated. This is the Moodle
login, not the SSH user, which is `admin` on both clouds.

**4.** Hand the site over. That IP is static and **will not change**, which is what makes
phase 2 uneventful.

### Phase 2 — your domain and certificate

**5.** Point the domain's A record at that IP. The nip.io site keeps serving while DNS
propagates.

**6.** Copy the certificate pair up:

```bash
cd terraform/deployments/school-b-aws
scp -i break-glass.pem fullchain.pem privkey.pem admin@<IP>:/tmp/
```

**7.** Run one command on the VM:

```bash
make ssh school-b-aws
cd /opt/moodle
sudo ./change-domain.sh --domain lms.example.com \
    --cert /tmp/fullchain.pem --key /tmp/privkey.pem
```

Confirm by typing the new domain; it takes about 30 seconds. `--letsencrypt` replaces both
certificate flags to get a fresh certificate instead. Afterwards update `moodle_domain` in
tfvars to match — Terraform cannot learn about the change, and `make deploys` reads that
value to show the real domain.

`fullchain.pem` must be the full chain with the leaf first, and the key must have no
passphrase; the script refuses before touching anything if either is wrong. Once it runs,
nip.io stops working and everyone logged in is signed out, so pick a quiet hour.

### Why this cannot be done from Terraform

Changing `moodle_domain` and applying does **not** move the site. `startup-script` /
`user_data` sit under `ignore_changes` so the VM is untouched, and even otherwise the image
writes `config.php` exactly once at install and the old URL is already scattered through
the database.

So `change-domain.sh` does it on the VM. It verifies the certificate matches the key,
covers the domain and carries a full chain, and that DNS already resolves here — all before
touching anything. Then it backs up the database, `config.php` and `moodledata`, enables
maintenance mode, rewrites `wwwroot`, runs `admin/tool/replace` across the database, moves
the no-reply address, purges caches and sessions, and verifies the result. Details and the
skip flags are in [../examples/traefik/README.md](../examples/traefik/README.md).

A longer domain than the old nip.io name is fine. Moodle refuses that by default and the
script passes `--shorten`; TEXT columns holding course content are still replaced whole,
and only fixed-length VARCHAR fields already near their limit lose the overflow.

## Domains and certificates

Leave `moodle_domain` empty and it is derived from the static IP as `moodle.<ip>.nip.io`.
nip.io resolves wildcards, so Traefik gets a real Let's Encrypt certificate on first boot
with no DNS setup. On AWS the Elastic IP attaches to the network interface **before** the
VM launches, so it boots already holding its final address.

To use your own domain from the start, set `moodle_domain`, apply, then point an A record
at `public_ip`; Traefik retries ACME until DNS catches up. When testing repeatedly, set
`acme_staging = true` to avoid rate limits — those certificates are not trusted.

## SSH access

Neither cloud opens port 22 to the internet by default.

| | Route | Mechanism |
|---|---|---|
| GCP | `make ssh <name>` | IAP TCP forwarding — port 22 only from `35.235.240.0/20`, plus OS Login so access is IAM rather than metadata keys |
| AWS | `make ssh <name>` | SSM Session Manager — the security group has **no** inbound 22 at all; the agent dials out |

One command for both clouds, and the same one once break-glass is on: `make ssh` prefers
`break-glass.pem` when it exists and otherwise uses the `ssh_command` output, which each
module fills in to suit its configuration.

Both routes need unexpired cloud CLI credentials. The Debian AMI ships without the SSM
agent, so bootstrap installs it first; if that fails, the SSM route never comes up.
`aws ssm start-session` also needs `brew install --cask session-manager-plugin`.

### Break-glass SSH

SSM and IAP fail the same way — expired token, or an agent that never started — and the VM
is unreachable. `ssh_allowed_cidrs` adds an independent route on both clouds:

```hcl
ssh_allowed_cidrs = ["1.2.3.4/32"]     # just your address
ssh_allowed_cidrs = ["0.0.0.0/0"]      # anywhere
```

Terraform generates an ED25519 key, writes `break-glass.pem` in the deployment directory
with mode 0600, and opens 22 to those CIDRs. An empty list means no key pair and port 22
fully closed. `make ssh <name>` prefers this key; by hand it is
`ssh -i break-glass.pem admin@$(terraform output -raw public_ip)` from the deployment
directory.

`0.0.0.0/0` is defensible because authentication is key-only: both Debian images disable
`PasswordAuthentication` and `PermitRootLogin`, so what you mainly gain is brute-force
noise in the logs, and you never lose access when your home IP changes.

Two differences worth knowing before there is real data:

- **AWS**: adding or removing this variable **replaces the VM**, because `key_name` is
  immutable on an EC2 instance.
- **GCP**: setting it **disables OS Login**, which deliberately ignores metadata keys.
  Access control moves from IAM to whoever holds the `.pem`.

## Open ports

| Port | Reason |
|---|---|
| 80/tcp | ACME HTTP-01 challenge, and the redirect to HTTPS |
| 443/tcp | HTTPS |
| 443/udp | HTTP/3 (QUIC) |
| 22/tcp | Only the CIDRs in `ssh_allowed_cidrs`. Empty list: GCP keeps the IAP range, AWS opens nothing. |

## Passwords

Terraform generates the Moodle admin and MariaDB passwords; read them with
`make output <name>`. Special characters are limited to `!@%^*-_=+` because Docker Compose
interpolates `.env`, where `$`, `` ` ``, `#`, quotes and backslashes would corrupt the
value.

State holds them in plaintext, which is why it lives in an encrypted, versioned bucket
rather than next to the code. `.gitignore` excludes `*.tfstate*`, `*.tfvars` at any depth
(except `*.tfvars.example`) and `*.pem`.

## First boot, and destroying

Bootstrap takes three to five minutes — install Docker, pull the image, let Moodle install
its schema. From the deployment directory:

```bash
eval "$(terraform output -raw bootstrap_log_command)"
curl -sI "$(terraform output -raw site_url)"           # 200
curl -s  "$(terraform output -raw site_url)/readyz"    # ready
```

`make destroy <name>` deletes the VM and its disk, so all Moodle data goes with it. Back up
`/opt/moodle/data` first if you need to keep anything.

Both modules set `ignore_changes` on the bootstrap script, and on `ami` for AWS because
`data.aws_ami` rolls forward weekly. Without it, a small compose edit or a new AMI would
have `apply` destroy a running VM and its data. To roll out a new compose file, SSH in and
run `cd /opt/moodle && docker compose up -d`, or taint the VM deliberately.

## AWS Local Zones

```hcl
availability_zone = "ap-southeast-1-han-1a"
instance_type     = "m7i.large"
```

Three things break `apply` halfway through if you get them wrong.

**The zone group must be opted in first**, which Terraform cannot do:

```bash
aws ec2 modify-availability-zone-group \
  --group-name ap-southeast-1-han-1 --opt-in-status opted-in
```

**There are no burstable families.** Hanoi offers only `c7i`, `m7i` and `r7i`, so the
default `t3.medium` is rejected. List what a zone offers:

```bash
aws ec2 describe-instance-type-offerings --location-type availability-zone \
  --filters Name=location,Values=ap-southeast-1-han-1a \
  --query 'sort(InstanceTypeOfferings[].InstanceType)' --output text
```

**The Elastic IP must come from the right network border group.** Hanoi is
`ap-southeast-1-han-1`, not `ap-southeast-1`. The module reads this from
`data.aws_availability_zone`, so setting `availability_zone` is enough; allocate in the
region's group instead and AWS returns `OperationNotPermitted: Cannot associate addresses
across network border groups`.

Local Zone subnets still reach the internet through the region's internet gateway, and SSM
works because the agent dials the regional endpoint. gp3 is supported. Instances cost more
than in-region with no burstable option, so do not leave one idle.
