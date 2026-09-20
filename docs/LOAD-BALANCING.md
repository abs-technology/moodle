# Moodle behind a proxy or load balancer

Set these before the **first** start and the generated `config.php` is already
correct. On an existing install, edit the two `[LB-ON]` blocks in `config.php`
instead — nothing has to be commented out.

| Variable | Traefik / Nginx / CloudFlare | GCP LB / AWS ALB | Standalone |
|---|---|---|---|
| `MOODLE_WWWROOT` | `https://lms.example.com` | `https://lms.example.com` | empty |
| `MOODLE_SSLPROXY` | `yes` | `yes` | `no` |
| `MOODLE_REVERSEPROXY` | **`no`** | **`no`** | `no` |
| `MOODLE_CLUSTER` | `yes` with 2+ nodes | `yes` | `no` |

## `MOODLE_REVERSEPROXY` almost always stays `no`

This is the setting everyone gets wrong, because the name suggests "there is a
reverse proxy in front of me". It does not mean that. Moodle 5.x contains this
check in `lib/setuplib.php`:

```php
if (!empty($CFG->reverseproxy) && $rurl['host'] === $wwwroot['host']
        && (empty($wwwroot['port']) || $rurl['port'] === $wwwroot['port'])) {
    throw new \moodle_exception('reverseproxyabused', 'error');
}
```

With `reverseproxy` enabled, Moodle **refuses** any request whose `Host` header
matches `wwwroot`, because it expects the proxy to rewrite `Host` to the node's
internal name. Traefik (`passHostHeader` defaults to true), AWS ALB and GCP all
forward the original `Host`, so turning `reverseproxy` on breaks every page with
HTTP 500:

> Reverse proxy enabled so the server cannot be accessed directly.

Only set `MOODLE_REVERSEPROXY=yes` if you deliberately configured the proxy to
replace the `Host` header, for example Traefik with
`passHostHeader: false` or nginx with `proxy_set_header Host backend-1.internal`.

`sslproxy` is what you actually need for a TLS-terminating proxy, and it is
independent of `reverseproxy`.

## What each setting does

| Setting | Why |
|---|---|
| `wwwroot` | Every node must return the same site URL. The dynamic fallback in `config.php` is wrapped in `if (empty($CFG->wwwroot))` and skips itself once this is set. |
| `sslproxy` | The proxy serves https and forwards plain http. Without it Moodle sees an http request against an https `wwwroot` and answers `303 See Other` to everything. |
| `reverseproxy` | See above — only for proxies that rewrite `Host`. |
| `session_handler_class` | Shared database sessions, otherwise users are logged out whenever the balancer moves them to another node. Enabled by `MOODLE_CLUSTER=yes`. |
| `localcachedir` | Moodle documents it as "not shared by cluster nodes" yet defaults it to `$CFG->dataroot/localcache`. Moved to container-local `/var/www/moodlelocalcache` by `MOODLE_CLUSTER=yes`. |

## Health endpoints

Never point a probe at `/login/index.php`. A balancer probes a node directly, so
the request carries an IP or `localhost` as its `Host` header and plain http as
its scheme — neither matches `wwwroot`, and Moodle answers `303 See Other`
instead of a health verdict. It also boots all of Moodle and creates a session
row on every probe.

The image ships two endpoints served from outside the Moodle tree, so they are
independent of `wwwroot`, sessions and proxy settings:

| Path | Meaning | Checks |
|---|---|---|
| `/healthz` | liveness | Apache and PHP-FPM respond. Always 200, even while the database is down. Used by the image's `HEALTHCHECK`. |
| `/readyz` | readiness | Also: `config.php` present, CLI maintenance mode off, database reachable and schema installed. 200 or 503. |

Point the load balancer at **`/readyz`** so unhealthy nodes drain. Neither path
is written to the access log, which keeps probe traffic out of your logs.

```bash
curl -s http://localhost:8080/healthz   # ok
curl -s http://localhost:8080/readyz    # ready  (503 "database unavailable" when down)
```

## Traefik in the same docker-compose

A complete runnable example lives in [`examples/traefik/`](../examples/traefik/),
with Let's Encrypt and bring-your-own-certificate variants. The essentials:

```yaml
moodle:
  image: abstechnology/moodle-standard:5.2.3
  environment:
    - MOODLE_WWWROOT=https://lms.example.com
    - MOODLE_SSLPROXY=yes
    - MOODLE_REVERSEPROXY=no
  labels:
    - traefik.enable=true
    - traefik.http.routers.moodle.rule=Host(`lms.example.com`)
    - traefik.http.routers.moodle.entrypoints=websecure
    - traefik.http.routers.moodle.tls=true
    - traefik.http.services.moodle.loadbalancer.server.port=8080
    - traefik.http.services.moodle.loadbalancer.healthcheck.path=/readyz
```

Traefik must reach port **8080** (plain http). Do not publish the container's
ports; Traefik is the only ingress.

## GCP external load balancer

Moodle runs as a backend service:

| Field | Value |
|---|---|
| Protocol | HTTP |
| Port | `8080` |
| Health check request path | `/readyz` |

Probes arrive from `35.191.0.0/16` and `130.211.0.0/22`; both are already listed
as `RemoteIPTrustedProxy` in the image's Apache config, so `X-Forwarded-For` is
honoured and Moodle logs the real client IP. A Google LB probe sends the backend
IP as its `Host` header, which is exactly why `/readyz` and not a Moodle URL
must be the target.

## AWS Application Load Balancer

Target group health check:

| Field | Value |
|---|---|
| Protocol | HTTP |
| Port | traffic port (`8080`) |
| Path | `/readyz` |
| Success codes | `200` |

ALB probes originate inside the VPC, covered by the `10.0.0.0/8` and
`172.16.0.0/12` trusted ranges. ALB cannot rewrite the `Host` header, so
`MOODLE_REVERSEPROXY` must stay `no`.

## What you still have to provide

Running more than one node needs shared state no container setting can create:

- **Shared `moodledata`.** Every node mounts the same `$CFG->dataroot` (NFS, EFS,
  Filestore). Without it, uploaded files exist on one node only.
- **One database** reachable from every node, with `MOODLE_CLUSTER=yes` so
  sessions live in it.
- **Node-local `localcachedir`.** Handled by the image; never point it at the
  shared mount.

If your proxy sits outside the private ranges above, add a
`RemoteIPTrustedProxy` line in `config/apache/sites/000-default.conf`.

## Troubleshooting

Check what the container actually runs with:

```bash
docker exec abs-moodle grep -nE 'wwwroot =|sslproxy|reverseproxy|session_handler|localcachedir' /var/www/html/config.php
```

**HTTP 500, "Reverse proxy enabled so the server cannot be accessed directly."**
`reverseproxy` is on while the proxy forwards the original `Host`. Set
`MOODLE_REVERSEPROXY=no`, or configure the proxy to rewrite `Host`.

**HTTP 303 on every request, including probes.**

```
"GET /login/index.php HTTP/1.1" 303 1505 "-" "curl/7.88.1"
```

From `initialise_fullme()`, which compares the request against `wwwroot`. Two
causes:

1. `sslproxy` is off while `wwwroot` is https and the proxy forwards plain http.
2. The probe targets a Moodle URL instead of `/healthz` or `/readyz`, so its
   `Host` (an IP or `localhost`) does not match `wwwroot`.

**Users randomly logged out.** More than one node without
`MOODLE_CLUSTER=yes`, so sessions are not shared.
