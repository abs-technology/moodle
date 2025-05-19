#!/bin/bash

# Script để chạy trong container Moodle và sửa lỗi SSL
echo "================ FIX SSL DIRECT ================"

# 1. Kiểm tra file cấu hình SSL
echo "Kiểm tra file cấu hình SSL:"
cat /etc/apache2/sites-available/default-ssl.conf
echo ""

# 2. Kiểm tra site-enabled
echo "Kiểm tra sites-enabled:"
ls -la /etc/apache2/sites-enabled/
echo ""

# 3. Tạo chứng chỉ mới trực tiếp vào thư mục Apache
echo "Tạo chứng chỉ mới trong /etc/apache2/ssl:"
mkdir -p /etc/apache2/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "/etc/apache2/ssl/ssl-cert-snakeoil.key" \
  -out "/etc/apache2/ssl/ssl-cert-snakeoil.crt" \
  -subj "/C=VN/ST=Hanoi/L=Hanoi/O=ABS Technology/OU=Moodle/CN=moodle.local"
echo ""

# 4. Cập nhật quyền
echo "Cập nhật quyền:"
chmod 644 /etc/apache2/ssl/ssl-cert-snakeoil.crt
chmod 640 /etc/apache2/ssl/ssl-cert-snakeoil.key
chown moodleuser:moodleuser /etc/apache2/ssl/ssl-cert-snakeoil.*
ls -la /etc/apache2/ssl/
echo ""

# 5. Tạo file cấu hình default-ssl.conf mới
echo "Tạo cấu hình SSL mới:"
cat > /etc/apache2/sites-available/default-ssl.conf << 'EOF'
<VirtualHost *:443>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/ssl-cert-snakeoil.crt
    SSLCertificateKeyFile /etc/apache2/ssl/ssl-cert-snakeoil.key

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
echo ""

# 6. Kích hoạt site SSL
echo "Kích hoạt site SSL:"
a2enmod ssl
a2ensite default-ssl
echo ""

# 7. Khởi động lại Apache
echo "Kiểm tra cấu hình Apache:"
apache2ctl configtest
echo ""

echo "================ HOÀN TẤT ================" 