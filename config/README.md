# Configuration Files

## 📁 Directory Structure

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

## 🔧 Usage

- **Development**: Copy `docker/.env.example` to `.env` and edit
- **Production**: Configure environment variables in docker-compose
- **Backup**: Backup entire `config/` directory to store configuration 