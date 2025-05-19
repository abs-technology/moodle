# Moodle 5.0 Container với Hỗ trợ SSL

Container Moodle 5.0 được phát triển bởi ABS Technology Joint Stock Company với hỗ trợ SSL. Container này đã được module hóa để dễ dàng bảo trì và mở rộng.

## Tính năng

- Apache + PHP 8.2
- Hỗ trợ SSL
- Tự động cài đặt Moodle
- Kiểm tra và xác minh cài đặt
- Hỗ trợ cơ sở dữ liệu MariaDB
- Tối ưu hóa cấu hình PHP cho Moodle
- Dịch vụ cron được tích hợp sẵn
- Bảo mật nâng cao cho thông tin nhạy cảm

## Hướng dẫn sử dụng

### Khởi động nhanh

1. Clone repository:
   ```bash
   git clone https://github.com/abs-vn/moodle-absi.git
   cd moodle-absi
   ```

2. Build và chạy container:
   ```bash
   docker-compose up -d
   ```

3. Truy cập Moodle:
   - **HTTP**: http://localhost
   - **HTTPS**: https://localhost

### Biến môi trường

Bạn có thể tùy chỉnh Moodle bằng cách thiết lập các biến môi trường trong file `docker-compose.yml`:

#### Biến cơ sở dữ liệu
- `MOODLE_DATABASE_TYPE`: Loại cơ sở dữ liệu (mariadb/mysqli)
- `MOODLE_DATABASE_HOST`: Máy chủ cơ sở dữ liệu 
- `MOODLE_DATABASE_PORT`: Cổng cơ sở dữ liệu
- `MOODLE_DATABASE_NAME`: Tên cơ sở dữ liệu
- `MOODLE_DATABASE_USER`: Tên người dùng cơ sở dữ liệu
- `MOODLE_DATABASE_PASSWORD`: Mật khẩu cơ sở dữ liệu
- `MOODLE_DATABASE_PREFIX`: Tiền tố bảng Moodle

#### Biến cài đặt admin
- `MOODLE_ADMIN_USER`: Tên người dùng admin
- `MOODLE_ADMIN_PASSWORD`: Mật khẩu admin (được truyền qua biến môi trường, không lưu trong image)
- `MOODLE_ADMIN_EMAIL`: Email admin

#### Biến cài đặt trang web
- `MOODLE_SITE_NAME`: Tên trang Moodle
- `MOODLE_SITE_FULLNAME`: Tên đầy đủ của trang
- `MOODLE_SITE_SHORTNAME`: Tên rút gọn của trang
- `MOODLE_WWWROOT`: URL gốc của trang web
- `MOODLE_DATAROOT`: Thư mục dữ liệu Moodle

#### Biến cài đặt SSL
- `MOODLE_ENABLE_SSL`: Bật/tắt SSL
- `MOODLE_SSLPROXY`: Cài đặt proxy SSL
- `MOODLE_REVERSEPROXY`: Cài đặt reverse proxy

#### Biến cài đặt ngôn ngữ
- `MOODLE_LANG`: Ngôn ngữ mặc định (vi, en, etc.)

#### Biến cài đặt PHP
- `PHP_MEMORY_LIMIT`: Giới hạn bộ nhớ PHP
- `PHP_UPLOAD_MAX_FILESIZE`: Kích thước tối đa file tải lên
- `PHP_POST_MAX_SIZE`: Kích thước tối đa của yêu cầu POST

#### Biến cài đặt tự động
- `MOODLE_SKIP_INSTALL`: Bỏ qua quá trình cài đặt
- `MOODLE_RECONFIGURE`: Cấu hình lại Moodle
- `MOODLE_AUTO_INSTALL`: Tự động cài đặt Moodle (true/false)

## Tính năng tự động cài đặt Moodle

Container hỗ trợ tự động cài đặt Moodle khi khởi động lần đầu. Chỉ cần đặt `MOODLE_AUTO_INSTALL=true` trong biến môi trường.

Tính năng này sẽ:
1. Kiểm tra xem Moodle đã được cài đặt chưa
2. Nếu chưa, tự động cài đặt Moodle với các thông số từ biến môi trường
3. Tạo tài khoản admin với thông tin được cung cấp
4. Cấu hình cơ sở dữ liệu và các cài đặt khác

## Bảo mật và xử lý mật khẩu

Container này được thiết kế với sự chú trọng đến bảo mật:

- **Không có mật khẩu mặc định**: Mật khẩu admin không được lưu trong image Docker, giúp tránh rủi ro bảo mật.
- **Quản lý mật khẩu an toàn**: Mật khẩu được cung cấp thông qua biến môi trường trong docker-compose.yml hoặc khi chạy container.
- **Xử lý linh hoạt**: Nếu không cung cấp mật khẩu admin, hệ thống sẽ sử dụng một mật khẩu mặc định chỉ trong quá trình cài đặt.

> **Lưu ý quan trọng**: Luôn thay đổi mật khẩu mặc định khi triển khai trong môi trường sản xuất bằng cách đặt biến môi trường `MOODLE_ADMIN_PASSWORD` với giá trị phức tạp.

## Cấu trúc thư mục

Container đã được module hóa với cấu trúc sau:
- `/opt/absi/entrypoint/lib/`: Các module cho entrypoint script
  - `moodle.sh`: Module chính quản lý cài đặt và tự động cài đặt Moodle
  - `ssl.sh`: Xử lý chứng chỉ SSL và cấu hình
  - `apache.sh`: Thiết lập và cấu hình Apache
  - `config.sh`: Tạo file cấu hình Moodle
  - `post_init.sh`: Các tác vụ sau khi cài đặt và xác minh
  - `setup.sh`: Thiết lập môi trường và cài đặt PHP extensions
  - và các module khác...

## Giấy phép

- Moodle: GPL-3.0
- Cấu trúc Docker và tùy chỉnh: Apache-2.0

Copyright (c) ABS Technology Joint Stock Company 