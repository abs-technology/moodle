# Running two or more Moodle nodes behind a load balancer

The `config.php` generated on first container start runs as a single node. To
put several nodes behind one balancer, uncomment the two blocks marked
`[LB-ON]`. Nothing has to be commented out — the single-node defaults switch
themselves off once you set `wwwroot` and `reverseproxy`.

## Block 1/2 — site address

```php
$CFG->wwwroot = 'https://your-domain.com';
```

Every node must return the exact same site URL. The dynamic fallback below it
is wrapped in `if (empty($CFG->wwwroot))` and skips itself once this is set.

## Block 2/2 — proxy and sessions

```php
$CFG->reverseproxy = true;
$CFG->sslproxy = true;
$CFG->session_handler_class = '\core\session\database';
$CFG->session_database_acquire_lock_timeout = 120;
```

| Setting | Why |
|---|---|
| `reverseproxy` | Trust the `X-Forwarded-*` headers. Required for any proxy in front of Moodle. |
| `sslproxy` | The proxy serves https and forwards plain http to the container. Required for Traefik, Nginx, CloudFlare and cloud balancers. Only leave it off if every node terminates its own TLS and Moodle itself receives https. |
| `session_*` | Keep sessions in the shared database, otherwise users are logged out whenever the balancer moves them to another node. |

## Outside config.php

Every node needs the **same shared `$CFG->dataroot`** storage (NFS, EFS,
Filestore). Without it, uploaded files and caches exist on one node only.

Apache already trusts the usual private ranges for `X-Forwarded-For`
(`10/8`, `172.16/12`, `192.168/16`) plus Google's balancer ranges. If your
proxy sits outside those, add a `RemoteIPTrustedProxy` line in
`config/apache/sites/000-default.conf`.

## Troubleshooting: Moodle answers `303 See Other` to everything

```
"GET /login/index.php HTTP/1.1" 303 1505 "-" "curl/7.88.1"
```

The redirect comes from `initialise_fullme()` in `lib/setuplib.php`, which
compares the incoming request against `wwwroot`. There are two causes:

1. **`reverseproxy` is off** and the request arrives on a host that is not the
   `wwwroot` host — a health check on `localhost`, or the balancer's own IP.
2. **`sslproxy` is off** while `wwwroot` is https and the proxy forwards plain
   http. This is the usual Traefik and Nginx mistake.

Enabling only `reverseproxy` silences cause 1 but not cause 2, so a
TLS-terminating proxy needs **both** flags.

## Traefik example

Traefik terminates TLS and forwards http to port 8080, so both flags are
required:

```yaml
services:
  moodle:
    image: abstechnology/moodle-standard:5.2.2-r4
    environment:
      - MOODLE_WWWROOT=https://lms.example.com
      - MOODLE_REVERSEPROXY=yes
      - MOODLE_SSLPROXY=yes
    labels:
      - traefik.enable=true
      - traefik.http.routers.moodle.rule=Host(`lms.example.com`)
      - traefik.http.routers.moodle.tls=true
      - traefik.http.services.moodle.loadbalancer.server.port=8080
```

Setting these three environment variables before the **first** start writes an
already load-balanced `config.php`, so there is nothing left to uncomment.
