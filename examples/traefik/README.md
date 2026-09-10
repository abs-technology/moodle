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

## Option A — certificate you already own

```bash
cp .env.example .env          # set MOODLE_DOMAIN
mkdir -p certs
cp /path/fullchain.pem certs/cert.pem
cp /path/privkey.pem  certs/key.pem
docker compose up -d
```

`dynamic/tls.yml` registers the pair as Traefik's default certificate, so it is
served for whatever host you configured.

## Option B — Let's Encrypt

`MOODLE_DOMAIN` must resolve publicly to this host, because the HTTP-01
challenge is answered on port 80.

```bash
cp .env.example .env          # set MOODLE_DOMAIN and ACME_EMAIL
docker compose -f docker-compose.yml -f docker-compose.letsencrypt.yml up -d
```

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
docker exec abs-moodle grep -nE 'wwwroot =|sslproxy|reverseproxy' /var/www/html/config.php
```

## Scaling to more than one node

`docker-compose.yml` runs a single Moodle container. Before scaling, read
[../../docs/LOAD-BALANCING.md](../../docs/LOAD-BALANCING.md): every node needs
the same shared `moodledata`, database sessions, and a node-local
`$CFG->localcachedir`. Setting `MOODLE_CLUSTER=yes` configures the last two for
you; the shared `moodledata` mount is yours to provide.
