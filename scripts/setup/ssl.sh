#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

. /scripts/lib/logging.sh

info "Setting up SSL certificates..."

# Tạo certificate cho localhost và IP của host
if [[ ! -f /etc/ssl/certs/localhost.crt ]] || [[ ! -f /etc/ssl/private/localhost.key ]]; then
    info "Generating SSL certificate for localhost..."
    
    # Tạo certificate với Subject Alternative Names
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/localhost.key \
        -out /etc/ssl/certs/localhost.crt \
        -subj "/C=VN/ST=HCM/L=HCM/O=ABSI/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,DNS:*.localhost,IP:127.0.0.1,IP:0.0.0.0" \
        2>/dev/null || {
        
        # Fallback cho OpenSSL cũ không hỗ trợ -addext
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
CN = localhost

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
IP.1 = 127.0.0.1
IP.2 = 0.0.0.0
EOF
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/ssl/private/localhost.key \
            -out /etc/ssl/certs/localhost.crt \
            -config /tmp/ssl.conf \
            -extensions v3_req
        
        rm -f /tmp/ssl.conf
    }
    
    # Set permissions
    chmod 600 /etc/ssl/private/localhost.key
    chmod 644 /etc/ssl/certs/localhost.crt
    
    info "SSL certificate generated successfully"
else
    info "SSL certificate already exists"
fi

info "SSL setup completed" 