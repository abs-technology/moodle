#!/usr/bin/env bash
# Move a running Moodle to a different public domain, and optionally to a
# certificate you own instead of Let's Encrypt. On an apply-ip host this also
# starts Traefik (the site begins as HTTP on the public IP).
#
#   sudo ./change-domain.sh --nip
#   sudo ./change-domain.sh --nip --email you@school.com
#   sudo ./change-domain.sh --domain lms.example.com --cert fullchain.pem --key privkey.pem
#   sudo ./change-domain.sh --domain lms.example.com --letsencrypt
#
# Changing MOODLE_DOMAIN alone is not enough. The image writes config.php once
# at install and never rewrites it, and Moodle stores absolute URLs throughout
# the database, so wwwroot and every stored URL have to be migrated too.
# -E so the ERR trap still fires from inside the helper functions.
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$0")")"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
info() { printf '%s==>%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%s[!]%s %s\n' "$YELLOW" "$NC" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

new_domain=""; cert_src=""; key_src=""; use_le=no; use_nip=no; acme_email=""
skip_backup=no; skip_data_backup=no; assume_yes=no; force=no

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)            new_domain="${2:?}"; shift 2 ;;
        --cert)              cert_src="${2:?}"; shift 2 ;;
        --key)               key_src="${2:?}"; shift 2 ;;
        --email)             acme_email="${2:?}"; shift 2 ;;
        --letsencrypt)       use_le=yes; shift ;;
        --nip)               use_nip=yes; use_le=yes; shift ;;
        --skip-backup)       skip_backup=yes; shift ;;
        --skip-data-backup)  skip_data_backup=yes; shift ;;
        --force)             force=yes; shift ;;
        -y|--yes)            assume_yes=yes; shift ;;
        -h|--help)           sed -n '2,12p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *)                   die "Unknown argument: $1" ;;
    esac
done

[[ $EUID -eq 0 ]]        || die "Run with sudo: config.php and data/ belong to uid 1000."
[[ -f docker-compose.yml && -f .env ]] || die "Run this from the compose directory."

if [[ "$use_nip" == yes ]]; then
    [[ -z "$new_domain$cert_src$key_src" ]] ||
        die "--nip cannot be combined with --domain, --cert or --key."
else
    [[ -n "$new_domain" ]] || die "--domain is required (or use --nip)."
    if [[ "$use_le" == yes ]]; then
        [[ -z "$cert_src$key_src" ]] || die "--letsencrypt and --cert/--key are mutually exclusive."
    else
        [[ -n "$cert_src" && -n "$key_src" ]] || die "Give --cert and --key, --letsencrypt, or --nip."
    fi
fi

compose() { docker compose "$@"; }

has_traefik() { grep -qE '^[[:space:]]*traefik:' docker-compose.yml; }

public_ipv4() {
    curl -fsS --max-time 10 https://checkip.amazonaws.com 2>/dev/null | tr -d '[:space:]' || true
}

enable_sslproxy() {
    local f=data/moodle/config.php
    if grep -qE '^\$CFG->sslproxy = true;' "$f"; then
        return
    fi
    if grep -qE '^// \$CFG->sslproxy = ' "$f"; then
        sed -i 's|^// \$CFG->sslproxy = .*|$CFG->sslproxy = true;|' "$f"
        return
    fi
    if grep -qE '^\$CFG->sslproxy = ' "$f"; then
        sed -i 's|^\$CFG->sslproxy = .*|$CFG->sslproxy = true;|' "$f"
        return
    fi
    die "Could not find \$CFG->sslproxy in config.php"
}

env_get() { sed -n "s/^$1=//p" .env | head -1; }
env_set() {
    if grep -q "^$1=" .env; then
        sed -i "s|^$1=.*|$1=$2|" .env
    else
        printf '%s=%s\n' "$1" "$2" >>.env
    fi
}

# Let's Encrypt rejects reserved suffixes and the IANA example.* names.
is_public_acme_email() {
    local e="$1" host tld
    [[ "$e" =~ ^[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$ ]] || return 1
    host="${e##*@}"
    tld="${host##*.}"
    case "${tld,,}" in
        test|local|localhost|invalid|example) return 1 ;;
    esac
    case "${host,,}" in
        example.com|example.net|example.org) return 1 ;;
    esac
    return 0
}

require_acme_email() {
    local current="${acme_email:-$(env_get ACME_EMAIL)}" entered=""
    if is_public_acme_email "$current"; then
        acme_email="$current"
        return
    fi
    [[ -n "$current" ]] && warn "ACME_EMAIL=$current is rejected by Let's Encrypt."
    if [[ "$assume_yes" == yes ]]; then
        die "Give --email you@your-domain.com"
    fi
    while true; do
        read -rp "Let's Encrypt contact email: " entered
        if is_public_acme_email "$entered"; then
            acme_email="$entered"
            return
        fi
        warn "Use a real public email, not example.com / .test / .local."
    done
}

old_domain="$(env_get MOODLE_DOMAIN)"
[[ -n "$old_domain" ]] || die "MOODLE_DOMAIN not found in .env."
[[ -f data/moodle/config.php ]] || die "data/moodle/config.php missing: Moodle is not installed yet."

promote_traefik=no
if ! has_traefik; then
    [[ -f docker-compose.traefik.yml ]] ||
        die "This stack has no Traefik and no docker-compose.traefik.yml to enable. ALB sites are not moved with this script."
    promote_traefik=yes
fi

public_ip="$(public_ipv4)"
if [[ "$use_nip" == yes ]]; then
    [[ -n "$public_ip" ]] || die "Cannot detect the public IPv4 for --nip."
    new_domain="moodle.${public_ip}.nip.io"
fi

[[ "$old_domain" != "$new_domain" ]] || die "Already serving $new_domain."

old_wwwroot="$(sed -n "s/^\$CFG->wwwroot = '\\(.*\\)';/\\1/p" data/moodle/config.php | head -1)"
[[ -n "$old_wwwroot" ]] || die "Could not read \$CFG->wwwroot from config.php."
new_wwwroot="https://${new_domain}"

if [[ "$use_le" == yes ]]; then
    require_acme_email
fi

# ---------------------------------------------------------------------------
# Validate everything before touching the running site.
# ---------------------------------------------------------------------------

if [[ "$use_le" == no ]]; then
    [[ -r "$cert_src" ]] || die "Cannot read $cert_src"
    [[ -r "$key_src"  ]] || die "Cannot read $key_src"

    openssl x509 -noout -in "$cert_src" 2>/dev/null || die "$cert_src is not a PEM certificate."
    # A passphrase-protected key would make Traefik prompt at startup, and it cannot.
    openssl pkey -noout -in "$key_src" -passin pass: 2>/dev/null || die "$key_src is not a PEM key, or has a passphrase."

    # A BEGIN line that is not exactly five dashes leaves the block invisible to
    # OpenSSL, which then silently reads the next certificate down instead. That
    # surfaces later as a key mismatch and sends you looking in the wrong place.
    blocks="$(grep -c 'BEGIN CERTIFICATE' "$cert_src" || true)"
    parsed="$(openssl crl2pkcs7 -nocrl -certfile "$cert_src" 2>/dev/null |
              openssl pkcs7 -print_certs -noout 2>/dev/null | grep -c '^subject=' || true)"
    if [[ "$blocks" != "$parsed" ]]; then
        warn "$cert_src has $blocks BEGIN CERTIFICATE lines but OpenSSL reads only $parsed."
        die "A PEM marker is malformed. Every one needs exactly five dashes: -----BEGIN CERTIFICATE-----"
    fi

    # openssl x509 reads the first block, so a chain in the wrong order fails the
    # key comparison below for a reason that has nothing to do with the key.
    if openssl x509 -noout -ext basicConstraints -in "$cert_src" 2>/dev/null | grep -q 'CA:TRUE'; then
        die "The first certificate in $cert_src is a CA. Put the leaf first, then the intermediates."
    fi

    cert_pub="$(openssl x509 -noout -pubkey -in "$cert_src")"
    key_pub="$(openssl pkey -pubout -in "$key_src" -passin pass:)"
    [[ "$cert_pub" == "$key_pub" ]] ||
        die "$key_src is not the key for the first certificate in $cert_src."

    openssl x509 -noout -checkend 0 -in "$cert_src" >/dev/null || die "Certificate has already expired."

    names="$(openssl x509 -noout -ext subjectAltName -in "$cert_src" 2>/dev/null | tr ',' '\n' | sed -n 's/.*DNS://p' | tr -d ' ')"
    wildcard="*.${new_domain#*.}"
    grep -qxF "$new_domain" <<<"$names" || grep -qxF "$wildcard" <<<"$names" ||
        die "$new_domain is not in the certificate SAN list: $(tr '\n' ' ' <<<"$names")"

    # Leaf-only chains pass in desktop browsers and fail in mobile apps.
    if [[ "$(grep -c 'BEGIN CERTIFICATE' "$cert_src")" -lt 2 ]]; then
        warn "$cert_src holds a single certificate. Traefik needs the full chain, leaf first."
        [[ "$force" == yes ]] || die "Append the intermediates, or re-run with --force."
    fi
fi

# Let's Encrypt answers the HTTP-01 challenge on this host, and Traefik will not
# serve the new router until the name points here either way.
resolved="$(getent ahostsv4 "$new_domain" 2>/dev/null | awk 'NR==1{print $1}' || true)"
if [[ -n "$public_ip" && "$resolved" != "$public_ip" ]]; then
    warn "$new_domain resolves to ${resolved:-nothing}, this host is $public_ip."
    warn "Point the A record first, or TLS will fail after the switch."
    [[ "$force" == yes ]] || die "Re-run with --force to proceed anyway."
fi

# tool_replace stops with "cannotfit" when the replacement is longer than the
# search string, and --shorten is only the flag that lets it past that check:
# replace_all_text() trims regardless. Only fixed-length CHAR columns are cut,
# to their own max_length; the TEXT columns holding course content are replaced
# whole. Decided here so a longer domain fails nothing halfway through.
shorten=""
if [[ ${#new_wwwroot} -gt ${#old_wwwroot} || ${#new_domain} -gt ${#old_domain} ]]; then
    shorten="--shorten"
    warn "$new_wwwroot is longer than $old_wwwroot, which Moodle refuses by default."
    warn "Proceeding: content columns are rewritten whole, and only short"
    warn "fixed-length fields already near their limit can lose the overflow."
fi

cat <<SUMMARY

  Domain        $old_domain  ->  $new_domain
  wwwroot       $old_wwwroot  ->  $new_wwwroot
  Frontend      $([[ "$promote_traefik" == yes ]] && echo "IP HTTP -> Traefik" || echo "Traefik (already running)")
  Certificate   $([[ "$use_le" == yes ]] && echo "Let's Encrypt ($acme_email)" || echo "$cert_src")
  Backup        $([[ "$skip_backup" == yes ]] && echo "skipped" || echo "database + config.php$([[ "$skip_data_backup" == yes ]] && echo "" || echo " + moodledata")")

  $old_wwwroot stops working. The database rewrite cannot be undone
  without restoring the backup, and every logged-in user is signed out.

SUMMARY

if [[ "$assume_yes" != yes ]]; then
    read -rp "Type the new domain to confirm: " answer
    [[ "$answer" == "$new_domain" ]] || die "Aborted."
fi

# Moodle 5.x serves from public/ but keeps the CLI shims at the root, so the two
# trees below are genuinely different. Probe before the backup, so a layout this
# script does not know about costs nothing.
in_container() {
    local candidate
    for candidate in "$@"; do
        if compose exec -T moodle test -e "$candidate"; then
            echo "$candidate"
            return 0
        fi
    done
    die "None of these exist in the container: $*"
}

maintenance_cli="$(in_container /var/www/html/admin/cli/maintenance.php \
                                /var/www/html/public/admin/cli/maintenance.php)"
cfg_cli="$(in_container /var/www/html/admin/cli/cfg.php \
                        /var/www/html/public/admin/cli/cfg.php)"
purge_cli="$(in_container /var/www/html/admin/cli/purge_caches.php \
                          /var/www/html/public/admin/cli/purge_caches.php)"
replace_cli="$(in_container /var/www/html/public/admin/tool/replace/cli/replace.php \
                            /var/www/html/admin/tool/replace/cli/replace.php)"

# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------

backup_dir="backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
if [[ "$skip_backup" == yes ]]; then
    warn "Backup skipped on request."
else
    info "Backing up to $backup_dir"

    cp .env "$backup_dir/env"
    cp data/moodle/config.php "$backup_dir/config.php"

    # Read the credentials inside the container so they never reach the host
    # process table.
    compose exec -T mariadb sh -c \
        'exec mariadb-dump --single-transaction --quick --routines --events \
             -u root -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' |
        gzip >"$backup_dir/database.sql.gz"

    if [[ "$skip_data_backup" == yes ]]; then
        warn "moodledata not backed up on request."
    else
        info "Archiving moodledata ($(du -sh data/moodledata | cut -f1)); this is the slow part."
        tar -C data -czf "$backup_dir/moodledata.tar.gz" moodledata
    fi

    du -sh "$backup_dir"
fi

trap 'warn "Failed partway through. Site may be in maintenance mode; backup is in $backup_dir."' ERR

# ---------------------------------------------------------------------------
# Switch
# ---------------------------------------------------------------------------

info "Enabling maintenance mode"
compose exec -T moodle php "$maintenance_cli" --enable

info "Rewriting wwwroot in config.php"
matches="$(grep -c '^\$CFG->wwwroot = ' data/moodle/config.php || true)"
[[ "$matches" == 1 ]] || die "Expected exactly one wwwroot assignment in config.php, found $matches. Fix it by hand."
sed -i "s|^\$CFG->wwwroot = .*|\$CFG->wwwroot = '${new_wwwroot}';|" data/moodle/config.php
info "Enabling sslproxy in config.php"
enable_sslproxy

if [[ "$promote_traefik" == yes ]]; then
    info "Enabling Traefik (replacing the IP-direct compose file)"
    mkdir -p "$backup_dir"
    cp docker-compose.yml "$backup_dir/docker-compose.yml.ip"
    cp docker-compose.traefik.yml docker-compose.yml
fi

info "Updating .env and the certificate source"
env_set MOODLE_DOMAIN "$new_domain"
if [[ "$use_le" == yes ]]; then
    env_set ACME_EMAIL "$acme_email"
    env_set TLS_CERTRESOLVER le
    # tls.yml pointing at an empty certs/ makes Traefik log a PEM error on every reload.
    rm -f dynamic/tls.yml certs/cert.pem certs/key.pem
else
    env_set TLS_CERTRESOLVER ""
    install -d -m 0755 certs dynamic
    install -m 0644 "$cert_src" certs/cert.pem
    install -m 0600 "$key_src" certs/key.pem
    if [[ -f dynamic/tls.yml.example ]]; then
        cp dynamic/tls.yml.example dynamic/tls.yml
    else
        cat >dynamic/tls.yml <<'TLS'
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /etc/traefik/certs/cert.pem
        keyFile: /etc/traefik/certs/key.pem
  certificates:
    - certFile: /etc/traefik/certs/cert.pem
      keyFile: /etc/traefik/certs/key.pem
TLS
    fi
fi

info "Recreating the stack"
compose up -d

info "Waiting for Moodle to answer"
for _ in $(seq 1 60); do
    compose exec -T moodle curl -fsS -o /dev/null http://localhost:8080/healthz 2>/dev/null && break
    sleep 5
done
compose exec -T moodle curl -fsS -o /dev/null http://localhost:8080/healthz ||
    die "Moodle did not come back. Logs: docker compose logs moodle"

replace_log="${backup_dir:-.}/replace.log"
run_replace() {
    local search="$1" replace="$2"
    info "Replacing $search in the database"
    if ! compose exec -T moodle php "$replace_cli" \
            --search="$search" --replace="$replace" \
            $shorten --non-interactive >>"$replace_log" 2>&1; then
        tail -20 "$replace_log" >&2
        die "Database replace failed. Full output in $replace_log"
    fi
}

: >"$replace_log"
if [[ "$old_wwwroot" != "$new_wwwroot" ]]; then
    run_replace "$old_wwwroot" "$new_wwwroot"
fi
if [[ "$old_domain" != "$new_domain" ]]; then
    run_replace "//$old_domain" "//$new_domain"
fi
tail -6 "$replace_log"

# tool_replace only rewrites the full URL, and deliberately skips siteidentifier.
# The no-reply sender is a bare address, so it survives with the old host.
noreply="$(compose exec -T moodle php "$cfg_cli" --name=noreplyaddress 2>/dev/null | tr -d '\r' || true)"
if [[ "$noreply" == *"@$old_domain" ]]; then
    info "Moving the no-reply sender to the new domain"
    compose exec -T moodle php "$cfg_cli" --name=noreplyaddress --set="noreply@$new_domain"
fi

info "Purging caches and sessions"
compose exec -T moodle php "$purge_cli"
find data/moodledata/sessions -name 'sess_*' -delete 2>/dev/null || true

info "Disabling maintenance mode"
compose exec -T moodle php "$maintenance_cli" --disable

trap - ERR

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------

# A first Let's Encrypt issue for the new name takes up to a minute, during which
# Traefik answers with its own self-signed default certificate.
info "Waiting for the new address to answer"
code=000
for _ in $(seq 1 12); do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://$new_domain/login/index.php" 2>/dev/null || echo 000)"
    [[ "$code" == 200 ]] && break
    sleep 10
done

echo | openssl s_client -servername "$new_domain" -connect "$new_domain:443" 2>/dev/null |
    openssl x509 -noout -issuer -subject -dates || warn "Could not read the certificate."

if [[ "$code" == 200 ]]; then
    info "https://$new_domain/login/index.php -> 200. Done."
else
    warn "https://$new_domain/login/index.php -> $code after two minutes."
    warn "Check: docker compose logs traefik"
fi

[[ "$skip_backup" == yes ]] || info "Backup kept in $backup_dir"
