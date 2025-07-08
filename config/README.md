# Configuration Files

## 📁 Cấu trúc thư mục

```
config/
├── apache/           # Apache web server configs
│   ├── apache2.conf         # Main Apache config
│   ├── sites/              # Virtual hosts
│   │   ├── 000-default.conf
│   │   └── 000-default-ssl.conf
│   └── conf/               # Additional configs
│       └── other-vhosts-access-log.conf
├── php/              # PHP configs
│   ├── php.ini             # Main PHP config
│   └── pool.d/             # PHP-FPM pools
│       └── www.conf
├── moodle/           # Moodle-specific configs (future)
└── docker/           # Docker environment configs
```

## 🔧 Sử dụng

- **Development**: Copy `docker/.env.example` thành `.env` và chỉnh sửa
- **Production**: Cấu hình environment variables trong docker-compose
- **Backup**: Backup toàn bộ thư mục `config/` để lưu trữ cấu hình 