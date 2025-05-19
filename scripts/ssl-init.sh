#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

set -e

# Sử dụng thư mục Apache thay vì thư mục hệ thống
CERT_DIR="/etc/apache2/ssl"
CERT_FILE="$CERT_DIR/moodle-cert.pem"
KEY_FILE="$CERT_DIR/moodle-key.pem"

echo "[SSL-INIT] Creating SSL certificate directories"
mkdir -p $CERT_DIR
chmod -R 755 $CERT_DIR

echo "[SSL-INIT] Generating SSL certificate"
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -subj "/C=VN/ST=Hanoi/L=Hanoi/O=ABS Technology/OU=Moodle/CN=moodle.local"

echo "[SSL-INIT] Setting permissions on SSL files"
chmod 644 "$CERT_FILE"
chmod 644 "$KEY_FILE"  # Apache cần quyền đọc cho key file
chown moodleuser:moodleuser "$CERT_FILE" "$KEY_FILE"

echo "[SSL-INIT] Checking SSL certificate files"
ls -la "$CERT_FILE"
ls -la "$KEY_FILE"

echo "[SSL-INIT] Verifying SSL certificate is readable"
if [ ! -s "$CERT_FILE" ]; then
  echo "[SSL-INIT] ERROR: Certificate file is empty or missing!"
  exit 1
fi

if [ ! -s "$KEY_FILE" ]; then
  echo "[SSL-INIT] ERROR: Private key file is empty or missing!"
  exit 1
fi

# Cập nhật cấu hình Apache SSL
echo "[SSL-INIT] Creating Apache SSL configuration"
cat > /etc/apache2/sites-available/default-ssl.conf << EOF
<VirtualHost *:443>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile $CERT_FILE
    SSLCertificateKeyFile $KEY_FILE
    
    # Strong SSL settings
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
    SSLHonorCipherOrder on
    
    <FilesMatch "\.(cgi|shtml|phtml|php)\$">
        SSLOptions +StdEnvVars
    </FilesMatch>
    
    <Directory /usr/lib/cgi-bin>
        SSLOptions +StdEnvVars
    </Directory>
</VirtualHost>
EOF

# Kích hoạt module SSL và site SSL
echo "[SSL-INIT] Enabling SSL module and site"
a2enmod ssl
a2ensite default-ssl

# Kiểm tra cấu hình Apache
echo "[SSL-INIT] Checking Apache configuration"
apache2ctl configtest || echo "[SSL-INIT] WARNING: Apache configuration test failed!"

echo "[SSL-INIT] SSL setup completed successfully" 