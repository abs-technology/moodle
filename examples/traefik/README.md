# Moodle behind Traefik in one docker-compose

Traefik terminates TLS and forwards plain http to the Moodle container on port
8080, so `docker-compose.yml` already sets:

```yaml
- MOODLE_WWWROOT=https://${MOODLE_DOMAIN}
- MOODLE_SSLPROXY=yes
- MOODLE_REVERSEPROXY=no
```

`MOODLE_REVERSEPROXY` staying `no` is deliberate, not an oversight. Traefik
forwards the original `Host` header, and Moodle 5.x rejects that combination
with HTTP 500 "Reverse proxy enabled so the server cannot be accessed
directly." Only turn it on if you also set `passHostHeader: false`. See
[../../docs/LOAD-BALANCING.md](../../docs/LOAD-BALANCING.md).

## Directory layout

Copy this whole directory to the host and run it from there:

```
traefik/                        # any name; see the note on project names below
├── docker-compose.yml          # Traefik + MariaDB + Moodle
├── docker-compose.letsencrypt.yml   # Option B override
├── .env                        # you create this; chmod 600
├── .env.example
├── certs/                      # Option A only: cert.pem + key.pem
├── dynamic/
│   └── tls.yml.example         # Option A only: copy to tls.yml
└── data/                       # created before the first start, uid 1000
    ├── moodle/                 # /var/www/html — code and config.php
    ├── moodledata/             # /var/www/moodledata — uploads, caches, sessions
    └── moodle-backups/         # /var/www/moodle-backups — pre-upgrade snapshots
```

Under Option B both `certs/` and `dynamic/` stay empty, and Traefik keeps the
certificate it obtained in a volume instead.

`data/` is bind-mounted, the same layout the root `docker-compose.yml` uses, so
`config.php` and `moodledata` stay readable on the host. It has to exist and
belong to uid 1000 before the first start — the container runs unprivileged as
`absiuser` and cannot chown a directory it does not own. Both options below
begin with that step.

Only two things stay in named volumes, prefixed with the compose project name,
which defaults to the directory name:

| Volume | Mounted at | Holds |
|---|---|---|
| `<project>_mariadb_data` | `/var/lib/mysql` | the database |
| `<project>_traefik_acme` | `/acme` | `acme.json`, the Let's Encrypt account and certificate |

Deleting `<project>_traefik_acme` makes Traefik request a fresh certificate on
the next start, so avoid it on shared test domains that rate-limit quickly.

The container names are fixed (`abs-traefik`, `abs-moodle`, `abs-mariadb`) and
Traefik binds ports 80 and 443, so only one stack from this example can run per
host. Running a second one — the root `docker-compose.yml`, for instance —
requires stopping this one first, even from a differently named directory.

## Option A — certificate you already own

```bash
cp .env.example .env          # set MOODLE_DOMAIN
mkdir -p data/moodle data/moodledata data/moodle-backups certs
sudo chown -R 1000:1000 data
cp dynamic/tls.yml.example dynamic/tls.yml
cp /path/fullchain.pem certs/cert.pem
cp /path/privkey.pem  certs/key.pem
docker compose up -d
```

`dynamic/tls.yml` registers the pair as Traefik's default certificate, so it is
served for whatever host you configured. It ships as `.example` because Traefik
logs `failed to find any PEM data in certificate input` when the file is active
but `certs/` is empty, which is the normal state under Option B.

## Option B — Let's Encrypt

`MOODLE_DOMAIN` must resolve publicly to this host, because the HTTP-01
challenge is answered on port 80.

```bash
cp .env.example .env          # set MOODLE_DOMAIN and ACME_EMAIL
mkdir -p data/moodle data/moodledata data/moodle-backups
sudo chown -R 1000:1000 data
docker compose -f docker-compose.yml -f docker-compose.letsencrypt.yml up -d
```

`ACME_EMAIL` needs a real public TLD. Let's Encrypt rejects account
registration with `contact email has invalid domain` for reserved suffixes such
as `.test` or `.local`.

While testing, uncomment the `caserver` line in
`docker-compose.letsencrypt.yml` to use the staging CA — the production
endpoint rate-limits per registered domain, which shared test domains such as
`nip.io` exhaust quickly.

## Health checks

Traefik probes `/readyz`, not `/login/index.php`:

```yaml
- traefik.http.services.moodle.loadbalancer.healthcheck.path=/readyz
```

`/readyz` is served outside the Moodle tree, so it answers a real verdict
instead of the redirect Moodle returns when the probe's Host header does not
match `wwwroot`. It reports 503 while the database is unreachable or the site is
in CLI maintenance mode, which is exactly when Traefik should stop sending
traffic. `/healthz` is the cheaper liveness variant used by the container's own
`HEALTHCHECK`.

## Verifying

```bash
curl -sI https://$MOODLE_DOMAIN/login/index.php | head -1   # HTTP/2 200
docker exec abs-moodle curl -s http://localhost:8080/healthz   # ok
docker exec abs-moodle curl -s http://localhost:8080/readyz    # ready
```

A `303` means `MOODLE_SSLPROXY` did not reach the container; a `500` means
`MOODLE_REVERSEPROXY` is on while Traefik forwards the original `Host`. Confirm
with:

```bash
grep -nE 'wwwroot =|sslproxy|reverseproxy' data/moodle/config.php
```

## Scaling to more than one node

`docker-compose.yml` runs a single Moodle container. Before scaling, read
[../../docs/LOAD-BALANCING.md](../../docs/LOAD-BALANCING.md): every node needs
the same shared `moodledata`, database sessions, and a node-local
`$CFG->localcachedir`. Setting `MOODLE_CLUSTER=yes` configures the last two for
you; the shared `moodledata` mount is yours to provide.
