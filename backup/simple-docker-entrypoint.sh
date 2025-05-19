#!/bin/bash
# Simple Docker entrypoint for Moodle 5.0 with SSL support

set -e

echo "=== MOODLE SIMPLE ENTRYPOINT ==="

# Tạo thư mục SSL
echo "[1/6] Tạo thư mục SSL"
mkdir -p /etc/apache2/ssl
chmod 755 /etc/apache2/ssl

# Tạo chứng chỉ SSL tự ký
echo "[2/6] Tạo chứng chỉ SSL tự ký"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "/etc/apache2/ssl/moodle.key" \
  -out "/etc/apache2/ssl/moodle.crt" \
  -subj "/C=VN/ST=Hanoi/L=Hanoi/O=ABS Technology/OU=Moodle/CN=moodle.local"

# Thiết lập quyền truy cập
echo "[3/6] Thiết lập quyền truy cập cho SSL"
chmod 644 /etc/apache2/ssl/moodle.crt
chmod 640 /etc/apache2/ssl/moodle.key
# Apache cần quyền đọc file key
chown moodleuser:moodleuser /etc/apache2/ssl/moodle.*
ls -la /etc/apache2/ssl/

# Cấu hình Apache SSL
echo "[4/6] Cấu hình Apache SSL"
cat > /etc/apache2/sites-available/default-ssl.conf << 'EOF'
<VirtualHost *:443>
    ServerAdmin webmaster@localhost
    ServerName moodle.local
    DocumentRoot /var/www/html

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/moodle.crt
    SSLCertificateKeyFile /etc/apache2/ssl/moodle.key

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch "\.(cgi|shtml|phtml|php)$">
        SSLOptions +StdEnvVars
    </FilesMatch>
    
    <Directory /usr/lib/cgi-bin>
        SSLOptions +StdEnvVars
    </Directory>
</VirtualHost>
EOF

# Thêm ServerName vào cấu hình Apache toàn cục
echo "[4b/6] Thêm ServerName vào cấu hình Apache toàn cục"
echo "ServerName moodle.local" > /etc/apache2/conf-available/servername.conf
a2enconf servername

# Kích hoạt SSL
echo "[5/6] Kích hoạt module và site SSL"
a2enmod ssl
a2ensite default-ssl

# Thiết lập quyền truy cập Apache cho moodleuser
echo "[6/6] Thiết lập quyền cho Apache và thư mục runtime"
mkdir -p /var/run/apache2
chmod -R 755 /var/run/apache2
chown -R moodleuser:moodleuser /var/run/apache2

mkdir -p /var/lock/apache2
chmod -R 755 /var/lock/apache2
chown -R moodleuser:moodleuser /var/lock/apache2

# Xóa PID file cũ nếu có
rm -f /var/run/apache2/apache2.pid

# Chuyển sang moodleuser để chạy Apache
echo "Chuyển sang moodleuser để chạy"
exec gosu moodleuser "$@" 