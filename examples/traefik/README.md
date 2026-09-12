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
├── docker-compose.yml          # Traefik + MariaDB + Moodle, the only compose file
├── .env                        # you create this; chmod 600
├── .env.example
├── change-domain.sh            # move a live site to another domain/certificate
├── certs/                      # own certificate only: cert.pem + key.pem
├── dynamic/
│   └── tls.yml.example         # own certificate only: copy to tls.yml
└── data/                       # created before the first start, uid 1000
    ├── moodle/                 # /var/www/html — code and config.php
    ├── moodledata/             # /var/www/moodledata — uploads, caches, sessions
    └── moodle-backups/         # /var/www/moodle-backups — pre-upgrade snapshots
```

With Let's Encrypt both `certs/` and `dynamic/` stay empty, and Traefik keeps
the certificate it obtained in a volume instead.

`data/` is bind-mounted, the same layout the root `docker-compose.yml` uses, so
`config.php` and `moodledata` stay readable on the host. It has to exist and
belong to uid 1000 before the first start — the container runs unprivileged as
`absiuser` and cannot chown a directory it does not own.

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

## Starting it

```bash
cp .env.example .env          # set MOODLE_DOMAIN
mkdir -p data/moodle data/moodledata data/moodle-backups
sudo chown -R 1000:1000 data
docker compose up -d
```

That is the whole command for either certificate source. `TLS_CERTRESOLVER` in
`.env` decides which one, so there is no second compose file and no `-f`.

## Where the certificate comes from

### `TLS_CERTRESOLVER=le` — Let's Encrypt (the default)

`MOODLE_DOMAIN` must resolve publicly to this host, because the HTTP-01
challenge is answered on port 80. `ACME_EMAIL` needs a real public TLD: Let's
Encrypt rejects reserved suffixes such as `.test` with `contact email has
invalid domain`.

While testing, set `ACME_CASERVER` to the staging endpoint. It issues untrusted
certificates but does not consume the production rate limit, which shared test
domains such as `nip.io` exhaust quickly.

### `TLS_CERTRESOLVER=` — a certificate you already own

Leave the value empty and Traefik never contacts a CA. Instead it serves the
default certificate registered by the file provider:

```bash
cp dynamic/tls.yml.example dynamic/tls.yml
mkdir -p certs
cp /path/fullchain.pem certs/cert.pem
cp /path/privkey.pem  certs/key.pem
```

`cert.pem` has to be the full chain, leaf first and then the intermediates. A
leaf-only file usually still passes in desktop browsers, which fetch the missing
issuer themselves, and then fails in mobile apps and anything that validates
strictly. The key must have no passphrase, because Traefik cannot be prompted
for one at startup. `MOODLE_DOMAIN` has to appear in the certificate's CN or
SAN: it is both Traefik's routing rule and Moodle's `$CFG->wwwroot`, so a
mismatch breaks TLS and the site address at the same time.

Renewal is yours to handle here. Traefik watches the `dynamic/` directory but
not reliably the contents of the certificate files that directory points at, so
restart it after replacing the pair:

```bash
docker compose restart traefik
```

`tls.yml` ships as `.example` because Traefik logs `failed to find any PEM data
in certificate input` when the file is active but `certs/` is empty, which is
the normal state under Let's Encrypt.

### Switching an already running stack

From Let's Encrypt to your own certificate:

```bash
sed -i 's/^TLS_CERTRESOLVER=.*/TLS_CERTRESOLVER=/' .env
cp dynamic/tls.yml.example dynamic/tls.yml
mkdir -p certs
cp /path/fullchain.pem certs/cert.pem
cp /path/privkey.pem  certs/key.pem
docker compose up -d
```

And back again:

```bash
sed -i 's/^TLS_CERTRESOLVER=.*/TLS_CERTRESOLVER=le/' .env
rm -f dynamic/tls.yml certs/cert.pem certs/key.pem
docker compose up -d
```

`up -d` recreates only the Moodle container, because the certificate source
lives in its labels; Traefik picks up the `dynamic/` change on its own. Neither
direction touches the database or `data/`, and the Let's Encrypt certificate
stays in `<project>_traefik_acme`, so going back does not order a new one.

Both commands above assume `MOODLE_DOMAIN` stays the same. Changing the domain
is a different, much larger operation — see below.

## Moving the site to a different domain

`change-domain.sh` exists because editing `.env` is not enough once the site has
data in it. Two things outlive a `docker compose up -d`:

- `config.php` is generated by the image exactly once, at install, and never
  rewritten afterwards, so `$CFG->wwwroot` keeps the old name.
- Moodle stores absolute URLs all over the database — course content, labels,
  forum posts, file links — and every one of them keeps pointing at the old
  host.

Point the new name's A record at this host first, then:

```bash
sudo ./change-domain.sh --domain lms.example.com \
    --cert /root/fullchain.pem --key /root/privkey.pem
```

Staying on Let's Encrypt under the new name instead:

```bash
sudo ./change-domain.sh --domain lms.example.com --letsencrypt
```

On an IP-direct host (`make apply-ip`) the same script starts Traefik first.
`--nip` is the no-DNS path: Let's Encrypt on `moodle.<public-ip>.nip.io`.

```bash
sudo ./change-domain.sh --nip
# or: sudo ./change-domain.sh --nip --email you@school.com
```

`ACME_EMAIL=admin@example.com` is rejected. The script prompts, or use `--email`.

The script validates before it touches anything: the key must match the
certificate and carry no passphrase, the new domain must be in the SAN list, the
chain must not be leaf-only, and the name must already resolve to this host.
`--force` overrides the last two.

Then, in order: back up the database, `config.php` and `moodledata` under
`backups/<timestamp>/`; enable maintenance mode; rewrite `wwwroot`; update
`.env` and install the certificate; recreate the stack; run Moodle's own
`admin/tool/replace` across the database; purge caches and sessions; disable
maintenance mode; and report which certificate is now being served.

`--skip-data-backup` drops only the `moodledata` archive, which is the slow part
on a site with many uploads. `--skip-backup` drops all of it — the database
rewrite is not reversible without those files.

Expect the site to be unreachable for as long as the replace step takes, every
session to be signed out, and the old hostname to stop working immediately.

Confirm which certificate is live:

```bash
echo | openssl s_client -servername "$MOODLE_DOMAIN" -connect "$MOODLE_DOMAIN:443" 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates
```

`issuer=C=US, O=Let's Encrypt, ...` means ACME is in use. Your own certificate
shows its own issuer, and `curl` without `-k` rejects it while it is self-signed.

## HTTP/3 (QUIC)

Enabled by default. Traefik keeps listening on TCP 443 and additionally serves
QUIC on **UDP 443**, advertising it through the `alt-svc` response header:

```
alt-svc: h3=":443"; ma=2592000
```

Clients decide for themselves. A browser or app that speaks HTTP/3 upgrades on
its next request; everything else negotiates HTTP/2 exactly as before, so
enabling this takes nothing away. Only routers with TLS can serve HTTP/3, which
is every router in this stack.

Two things are required beyond the defaults in `docker-compose.yml`, and both
are already set there: the entrypoint flag, and publishing the UDP port, which
Docker does not do implicitly.

```yaml
- --entrypoints.websecure.http3=${TRAEFIK_HTTP3:-true}
ports:
  - "443:443/tcp"
  - "443:443/udp"
```

**Open UDP 443 in every firewall in front of this host.** Host firewalls, cloud
security groups and NAT rules commonly allow TCP 443 only. If UDP is dropped
silently rather than rejected, browsers see the `alt-svc` promise, attempt QUIC,
and wait for a timeout before falling back — slower than never advertising it.
Set `TRAEFIK_HTTP3=false` in `.env` and `docker compose up -d` when you cannot
open UDP.

If the public port differs from 443 — behind a port-mapping NAT, for instance —
add the advertised port so `alt-svc` names the port clients can actually reach:

```yaml
- --entrypoints.websecure.http3.advertisedport=8443
```

Verify it, with a client that actually supports HTTP/3 — the curl shipped with
macOS does not:

```bash
curl -sI https://$MOODLE_DOMAIN/ | grep -i alt-svc     # h3=":443"; ma=2592000
docker run --rm ymuski/curl-http3 curl -sS --http3-only -o /dev/null \
  -w 'HTTP/%{http_version} %{http_code}\n' https://$MOODLE_DOMAIN/
```

The second command prints `HTTP/3 303` when QUIC works end to end. `QUIC:
connection to ... refused` means UDP 443 is not reaching Traefik.

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
