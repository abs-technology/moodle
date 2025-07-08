# Absi Technology Moodle LMS Docker Setup

A production-ready Docker setup for Moodle 5.0.1 with MariaDB, optimized for performance and scalability.

## Features

- **Moodle 5.0.1** - Latest stable version
- **MariaDB 11.7.2** - High-performance database
- **PHP 8.2** with FPM and OPcache optimization
- **Apache 2.4** with SSL support
- **Security hardened** - Production-ready security configurations
- **Docker optimized** - Easy deployment and scaling

## Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- At least 4GB RAM available
- 20GB+ free disk space

### 1. Clone and Setup

```bash
git clone <repository-url>
cd absi-tech-moodle
cp env.example .env
```

### 2. Configure Environment

Edit `.env` file with your settings:

```bash
# Database Configuration
MARIADB_ROOT_PASSWORD=your_strong_root_password
MARIADB_PASSWORD=your_strong_db_password

# Moodle Admin
MOODLE_USERNAME=admin
MOODLE_PASSWORD=your_admin_password
MOODLE_EMAIL=admin@yourdomain.com

# Site Configuration
MOODLE_SITE_NAME=Your School Name
```

### 3. Deploy

```bash
# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f moodle
```

### 4. Access Moodle

- **HTTP**: http://localhost
- **HTTPS**: https://localhost (self-signed certificate)
- **Admin Panel**: /admin/
- **Login**: Use credentials from `.env`

## Configuration Reference

### Environment Variables

#### Database Settings
```env
MARIADB_ROOT_PASSWORD=root_password
MARIADB_DATABASE=absi_moodle_db
MARIADB_USER=absi_moodle_user
MARIADB_PASSWORD=db_password
```

#### Moodle Admin Settings
```env
MOODLE_USERNAME=admin
MOODLE_PASSWORD=admin_password
MOODLE_EMAIL=admin@domain.com
```

#### Site Configuration
```env
MOODLE_SITE_NAME=School Name
MOODLE_SITE_FULLNAME=Full School Name
MOODLE_SITE_SHORTNAME=SCHOOL
MOODLE_CRON_MINUTES=5
```

#### PHP Performance Settings
```env
PHP_MEMORY_LIMIT=512M
PHP_MAX_INPUT_VARS=5000
PHP_MAX_FILE_UPLOADS=200
PHP_POST_MAX_SIZE=2G
PHP_UPLOAD_MAX_FILESIZE=2G
PHP_MAX_EXECUTION_TIME=256
```



## Production Deployment

### 1. Security Setup

Generate strong passwords:
```bash
# Root password (32 chars)
openssl rand -base64 32

# Database password (24 chars)  
openssl rand -base64 24

# Admin password (16 chars)
openssl rand -base64 16
```

### 2. SSL Certificates

Replace self-signed certificates:
```bash
# Copy your certificates
cp your-cert.crt config/ssl/localhost.crt
cp your-key.key config/ssl/localhost.key

# Restart to apply
docker-compose restart moodle
```

### 3. Performance Tuning

#### Resource Limits

Adjust based on your server:
```yaml
# In docker-compose.yml
services:
  moodle:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
```

#### Database Optimization

For high-traffic sites:
```yaml
# Add to mariadb service
command:
  - '--character-set-server=utf8mb4'
  - '--collation-server=utf8mb4_unicode_ci'
  - '--innodb-buffer-pool-size=1G'
  - '--innodb-log-file-size=256M'
```

## Maintenance

### Backup

```bash
# Database backup
docker-compose exec mariadb mysqldump -u root -p absi_moodle_db > backup.sql

# Moodle data backup
tar -czf moodledata-backup.tar.gz ./data/moodledata/

# Full backup
docker-compose exec moodle tar -czf /backup/full-backup.tar.gz /var/www/html /var/www/moodledata
```

### Updates

```bash
# Pull latest images
docker-compose pull

# Restart with new images
docker-compose down
docker-compose up -d

# Check logs
docker-compose logs -f moodle
```

### Monitoring

```bash
# Check service health
docker-compose ps

# View resource usage
docker stats

# Database status
docker-compose exec mariadb mysql -u root -p -e "SHOW PROCESSLIST;"

# PHP-FPM status
docker-compose exec moodle curl http://localhost/fpm-status
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Failed
```bash
# Check database status
docker-compose logs mariadb

# Test connection
docker-compose exec moodle php -r "new PDO('mysql:host=mariadb;dbname=absi_moodle_db', 'user', 'pass');"
```

#### 2. File Upload Issues
- Check `PHP_UPLOAD_MAX_FILESIZE` and `PHP_POST_MAX_SIZE`
- Verify disk space: `df -h`
- Check permissions: `ls -la ./data/moodledata/`

#### 3. Performance Issues
```bash
# Check PHP-FPM pool status
docker-compose exec moodle curl http://localhost/fpm-ping

# Monitor slow queries
docker-compose exec mariadb mysql -u root -p -e "SET GLOBAL slow_query_log = 'ON';"

# Check OPcache status
docker-compose exec moodle php -r "print_r(opcache_get_status());"
```

#### 4. SSL Certificate Issues
```bash
# Generate new self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout config/ssl/localhost.key \
  -out config/ssl/localhost.crt \
  -subj "/C=VN/ST=HCM/L=HCM/O=Absi/CN=localhost"
```

### Logs Access

```bash
# All services
docker-compose logs

# Specific service
docker-compose logs moodle
docker-compose logs mariadb

# Follow logs
docker-compose logs -f --tail=100 moodle

# Apache logs
docker-compose exec moodle tail -f /var/log/apache2/error.log
docker-compose exec moodle tail -f /var/log/apache2/access.log
```

## Development

### Local Development Setup

```bash
# Mount source code for development
docker-compose -f docker-compose.dev.yml up -d

# Access container shell
docker-compose exec moodle bash

# Install Moodle plugins
docker-compose exec moodle php admin/cli/install_plugins.php
```

### Custom Configurations

- PHP settings: Edit `config/php/php.ini`
- Apache settings: Edit `config/apache/apache2.conf`
- Database settings: Edit `docker-compose.yml` MariaDB command

## Architecture

```
Docker Host
┌─────────────────────────────────────────────────────┐
│                                                     │
│  ┌─────────────────────┐    ┌─────────────────────┐ │
│  │   Moodle Container  │    │  MariaDB Container  │ │
│  │  ┌───────────────┐  │    │  ┌───────────────┐  │ │
│  │  │    Apache     │  │    │  │   MariaDB     │  │ │
│  │  │  + PHP-FPM    │  │◄───┤  │   Database    │  │ │
│  │  │  Port 80/443  │  │    │  │   Port 3306   │  │ │
│  │  └───────────────┘  │    │  └───────────────┘  │ │
│  │  ┌───────────────┐  │    │                     │ │
│  │  │    Moodle     │  │    │  Volume:            │ │
│  │  │ Application   │  │    │  mariadb_data       │ │
│  │  │ /var/www/html │  │    │                     │ │
│  │  └───────────────┘  │    └─────────────────────┘ │
│  │                     │                            │
│  │  Volumes:           │                            │
│  │  ./data/moodle      │                            │
│  │  ./data/moodledata  │                            │
│  └─────────────────────┘                            │
│                                                     │
│  Network: moodle_network                            │
└─────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────┐
│   Host Ports    │
│   80 → 80       │
│   443 → 443     │
└─────────────────┘
```

## Support

### Community
- [Moodle Community](https://moodle.org/community/)
- [Moodle Documentation](https://docs.moodle.org/)

### Commercial Support
Contact: support@absi.edu.vn

## License

This Docker setup is provided under MIT License. Moodle itself is licensed under GPL v3+.

---

**Absi Technology** - Educational Technology Solutions 