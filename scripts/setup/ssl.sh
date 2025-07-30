#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh
. /scripts/lib/config.sh

# Load centralized configuration
load_config

info "Setting up SSL certificates..."

# Create certificate for server name and host IP
if [[ ! -f "$SSL_CERT_FILE" ]] || [[ ! -f "$SSL_KEY_FILE" ]]; then
    info "Generating SSL certificate for $WEB_SERVER_NAME..."
    
    # Create certificate with Subject Alternative Names
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_KEY_FILE" \
        -out "$SSL_CERT_FILE" \
        -subj "/C=$SSL_COUNTRY/ST=$SSL_STATE/L=$SSL_CITY/O=$SSL_ORGANIZATION/CN=$SSL_COMMON_NAME" \
        -addext "subjectAltName=DNS:$WEB_SERVER_NAME,DNS:*.$WEB_SERVER_NAME,IP:127.0.0.1,IP:0.0.0.0" \
        2>/dev/null || {
        
        # Fallback for old OpenSSL that doesn't support -addext
        cat > /tmp/ssl.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = VN
ST = HCM
L = HCM
O = ABSI
CN = $SSL_COMMON_NAME

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $WEB_SERVER_NAME
DNS.2 = *.$WEB_SERVER_NAME
IP.1 = 127.0.0.1
IP.2 = 0.0.0.0
EOF
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$SSL_KEY_FILE" \
            -out "$SSL_CERT_FILE" \
            -config /tmp/ssl.conf \
            -extensions v3_req
        
        rm -f /tmp/ssl.conf
    }
    
    # Set permissions
    chmod 600 "$SSL_KEY_FILE"
    chmod 644 "$SSL_CERT_FILE"
    
    info "SSL certificate generated successfully"
else
    info "SSL certificate already exists"
fi

info "SSL setup completed" 