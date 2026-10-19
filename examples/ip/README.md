# Moodle on a public IP (no proxy)

MariaDB + Moodle only. The container publishes **TCP 80**. First boot does
**not** pin `$CFG->wwwroot` to the public IP — Moodle follows the request
`Host` (whatever IP the VM has now, or localhost). There is no Traefik and
no load balancer on first boot.

`make apply aws-traefik` / `gcp-traefik` still uses [../traefik](../traefik). `make apply gcp-alb` still uses
[../alb](../alb). This directory is `make apply-ip` only.

## First start

```bash
cp .env.example .env          # set MOODLE_DOMAIN to the public IPv4
mkdir -p data/moodle data/moodledata data/moodle-backups
sudo chown -R 1000:1000 data
docker compose up -d
```

Open `http://$MOODLE_DOMAIN`. There is no TLS until you run `change-domain.sh`.

`docker-compose.traefik.yml` is written next to this file on a Terraform VM
(`/opt/moodle`). Do not start it yourself — the script below swaps it in.

## Move to a domain (on the VM)

`change-domain.sh` lives in `/opt/moodle` after `make apply-ip`. It turns this
stack into the Traefik stack, then migrates wwwroot and every stored URL.

### Kèo

| Bước | Ai làm | IP public |
|---|---|---|
| First boot | Compose IP, không pin wwwroot | Vào bằng IP **đang có** trên VM (`Host`) |
| `--nip` | Script `curl https://checkip.amazonaws.com` | Tự ghép `moodle.<ip-vừa-đo>.nip.io`. Chỉ gõ tên site |
| `--domain` | Bạn trỏ A record | Script đo lại IP, so với DNS; lệch thì dừng (trừ `--force`) |

Không cần điền IP vào lệnh. Terraform `public_ip` chỉ để bạn ghi nhớ / trỏ DNS.

nip.io + Let's Encrypt (no DNS work). `admin@example.com` is rejected:

```bash
cd /opt/moodle
sudo ./change-domain.sh --nip
# or: sudo ./change-domain.sh --nip --name moodle --email you@school.com
```

Type the site name only (`moodle`). The host becomes `<name>.<public-ip>.nip.io`.

That serves `https://moodle.<public-ip>.nip.io`. Then set `moodle_domain` in
that site’s `terraform.tfvars` to the same host. Do not apply.

Your own name and certificate:

```bash
sudo ./change-domain.sh --domain lms.example.com \
    --cert /root/fullchain.pem --key /root/privkey.pem
```

Let's Encrypt on a name you already pointed here:

```bash
sudo ./change-domain.sh --domain lms.example.com --letsencrypt
```

After any of those, Moodle is only reachable on the new https name. Port 80
becomes Traefik's HTTP→HTTPS redirect. Editing `.env` alone is not enough —
see [../traefik/README.md](../traefik/README.md).

Back to this IP-direct stack:

```bash
sudo ./change-domain.sh --ip
```
