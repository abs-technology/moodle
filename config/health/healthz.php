<?php
/**
 * Liveness probe — "is this container still serving PHP?".
 *
 * Deliberately does not load Moodle. A proxy or load balancer probes a node
 * directly (http://<node-ip>:8080/healthz), so the Host header and the scheme
 * do not match $CFG->wwwroot. Booting Moodle would make initialise_fullme()
 * answer 303 See Other instead of a health verdict, so this file stays
 * independent of wwwroot, sessions and the database.
 *
 * Use /readyz instead when the balancer should also drain nodes whose database
 * is unreachable or which are in maintenance mode.
 */

header('Content-Type: text/plain; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate');

http_response_code(200);
echo "ok\n";
