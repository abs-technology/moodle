#!/usr/bin/env bash
# aws-alb only. Let's Encrypt HTTP-01 (nip.io works; ACM DNS-01 does not),
# then re-import the cert onto the ACM ARN Terraform already attached to the ALB.
set -euo pipefail

exec >>/var/log/absi-alb-acme.log 2>&1
echo "=== $(date -Is) ==="

# shellcheck disable=SC1091
source /etc/absi-alb-acme.env

: "${ACME_EMAIL:?}" "${MOODLE_DOMAIN:?}" "${ACM_CERTIFICATE_ARN:?}"
: "${AWS_DEFAULT_REGION:?}" "${ACME_WEBROOT:?}"

LEGO_VERSION=4.22.2
LEGO_BIN=/usr/local/bin/lego
LEGO_PATH="${ACME_WEBROOT}/lego"
CERT="${LEGO_PATH}/certificates/${MOODLE_DOMAIN}.crt"
KEY="${LEGO_PATH}/certificates/${MOODLE_DOMAIN}.key"
ISSUER="${LEGO_PATH}/certificates/${MOODLE_DOMAIN}.issuer.crt"

if [[ ! -x "$LEGO_BIN" ]]; then
    tmp=$(mktemp -d)
    curl -fsSL -o "$tmp/lego.tar.gz" \
        "https://github.com/go-acme/lego/releases/download/v${LEGO_VERSION}/lego_v${LEGO_VERSION}_linux_amd64.tar.gz"
    tar -xzf "$tmp/lego.tar.gz" -C "$tmp" lego
    install -m 0755 "$tmp/lego" "$LEGO_BIN"
    rm -rf "$tmp"
fi

install -d -m 0755 "$ACME_WEBROOT/.well-known/acme-challenge" "$LEGO_PATH"

server=()
if [[ "${ACME_STAGING:-no}" == yes ]]; then
    server=(--server https://acme-staging-v02.api.letsencrypt.org/directory)
fi

imported_stamp="${ACME_WEBROOT}/.imported"

if [[ -f "$CERT" && -f "$imported_stamp" ]] &&
    openssl x509 -checkend $((30 * 24 * 3600)) -noout -in "$CERT"; then
    echo "already imported and not due for renewal"
    exit 0
fi

# ACM refuses a re-import that changes the key algorithm. Terraform's
# placeholder is RSA-2048, so lego must not use its default ECDSA P-256.
if [[ -f "$KEY" ]] && ! openssl rsa -in "$KEY" -check -noout >/dev/null 2>&1; then
    echo "dropping non-RSA lego key so the ACM re-import can match RSA-2048"
    rm -f "$CERT" "$KEY" "$ISSUER" "$imported_stamp"
fi

lego_base=(
    "$LEGO_BIN"
    --accept-tos
    --email "$ACME_EMAIL"
    --domains "$MOODLE_DOMAIN"
    --key-type rsa2048
    --http
    --http.webroot "$ACME_WEBROOT"
    --path "$LEGO_PATH"
    "${server[@]}"
)

if [[ ! -f "$CERT" ]]; then
    "${lego_base[@]}" run
else
    "${lego_base[@]}" renew --days 30 || true
fi

[[ -f "$CERT" && -f "$KEY" ]] || {
    echo "lego did not write $CERT"
    exit 1
}

# ACM ImportCertificate: --certificate is the leaf only. lego's .crt is the
# full chain (leaf + intermediates), which AWS rejects as "more than one
# certificate".
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
awk 'BEGIN{n=0} /BEGIN CERTIFICATE/{n++} n==1{print} /END CERTIFICATE/ && n==1{exit}' "$CERT" >"$work/leaf.pem"
awk 'BEGIN{n=0} /BEGIN CERTIFICATE/{n++} n>1{print}' "$CERT" >"$work/chain.pem"
if [[ ! -s "$work/chain.pem" && -f "$ISSUER" ]]; then
    cp "$ISSUER" "$work/chain.pem"
fi

import=(aws acm import-certificate
    --region "$AWS_DEFAULT_REGION"
    --certificate-arn "$ACM_CERTIFICATE_ARN"
    --certificate "fileb://${work}/leaf.pem"
    --private-key "fileb://${KEY}")
[[ -s "$work/chain.pem" ]] && import+=(--certificate-chain "fileb://${work}/chain.pem")
"${import[@]}"
touch "$imported_stamp"

echo "imported $MOODLE_DOMAIN onto $ACM_CERTIFICATE_ARN"
