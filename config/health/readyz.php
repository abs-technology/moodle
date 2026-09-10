<?php
/**
 * Readiness probe — "should a load balancer send traffic to this node?".
 *
 * Answers 200 only when Moodle is installed, not in CLI maintenance mode and
 * able to reach its database. Anything else answers 503 so GCP/AWS health
 * checks drain the node instead of serving errors to learners.
 *
 * Moodle's config.php is loaded with ABORT_AFTER_CONFIG so that $CFG holds the
 * authoritative database credentials without running initialise_fullme(). That
 * matters because the balancer probes this node by IP: a full Moodle bootstrap
 * would answer 303 See Other for any host that differs from $CFG->wwwroot.
 * Loading config.php also gives CLI maintenance mode for free — lib/setup.php
 * emits its own 503 and exits before we get here.
 *
 * The response body never carries diagnostics: this endpoint is reachable by
 * anyone who can reach the node.
 */

header('Content-Type: text/plain; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate');

/** Answer and stop. */
function absi_verdict(int $status, string $body): never {
    http_response_code($status);
    echo $body . "\n";
    exit;
}

$configfile = '/var/www/html/config.php';
if (!is_file($configfile)) {
    // First boot has not written config.php yet, so Moodle cannot serve.
    absi_verdict(503, 'not installed');
}

// Keep a failure inside config.php from leaking a stack trace to the probe.
ini_set('display_errors', '0');

define('ABORT_AFTER_CONFIG', true);
try {
    require($configfile);
} catch (Throwable $e) {
    absi_verdict(503, 'config error');
}

if (empty($CFG->dbhost) || empty($CFG->dbname)) {
    absi_verdict(503, 'config incomplete');
}

$port = (int)($CFG->dboptions['dbport'] ?? 3306);
$socket = (string)($CFG->dboptions['dbsocket'] ?? '');
$dsn = $socket !== ''
    ? sprintf('mysql:unix_socket=%s;dbname=%s', $socket, $CFG->dbname)
    : sprintf('mysql:host=%s;port=%d;dbname=%s', $CFG->dbhost, $port, $CFG->dbname);

try {
    $pdo = new PDO($dsn, $CFG->dbuser, $CFG->dbpass, [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT            => 3,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_NUM,
    ]);
    // Read one real row: proves the schema is installed, not just that the
    // server accepts connections.
    $table = ($CFG->prefix ?? 'mdl_') . 'config';
    $pdo->query('SELECT 1 FROM ' . $table . ' LIMIT 1')->fetch();
} catch (Throwable $e) {
    absi_verdict(503, 'database unavailable');
}

absi_verdict(200, 'ready');
