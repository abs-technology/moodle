#!/bin/bash
# Script để kiểm tra cài đặt SSL trong container

set -e

echo "=== Kiểm tra cấu hình Apache SSL ==="
echo "1. Kiểm tra thư mục sites-enabled:"
ls -la /etc/apache2/sites-enabled/

echo -e "\n2. Kiểm tra nội dung file default-ssl.conf nếu tồn tại:"
cat /etc/apache2/sites-available/default-ssl.conf || echo "File không tồn tại!"

echo -e "\n3. Kiểm tra symbolic link đến default-ssl.conf:"
ls -la /etc/apache2/sites-enabled/default-ssl.conf || echo "Symbolic link không tồn tại!"

echo -e "\n4. Kiểm tra thư mục chứa chứng chỉ SSL:"
ls -la /etc/apache2/ssl/ || echo "Thư mục không tồn tại!"
ls -la /etc/ssl/certs/ || echo "Thư mục không tồn tại!"
ls -la /etc/ssl/private/ || echo "Thư mục không tồn tại!"

echo -e "\n5. Kiểm tra module SSL đã được kích hoạt:"
apache2ctl -M | grep ssl || echo "Module SSL chưa được kích hoạt!"

echo -e "\n6. Kiểm tra cấu hình apache2.conf:"
grep -A 5 "SSLCertificate" /etc/apache2/apache2.conf || echo "Không tìm thấy cấu hình SSL trong apache2.conf"

echo -e "\n7. Kiểm tra site đã được kích hoạt:"
a2query -s

echo -e "\n=== Kiểm tra hoàn tất ===" 