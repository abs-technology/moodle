# Moodle LMS - Docker Image

![Docker Pulls](https://img.shields.io/docker/pulls/abstechnology/moodle-standard)
![Docker Stars](https://img.shields.io/docker/stars/abstechnology/moodle-standard)
![Image Size](https://img.shields.io/docker/image-size/abstechnology/moodle-standard)

Production-ready Docker image for **Moodle 5.0.1** LMS with MariaDB. Simple deployment using Docker Compose and environment variables.

## 🚀 Quick Start

### 1. Create docker-compose.yml

```yaml
services:
  mariadb:
    image: mariadb:11.7.2
    container_name: absi_mariadb
    environment:
      - MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
      - MARIADB_USER=${MARIADB_USER}
      - MARIADB_PASSWORD=${MARIADB_PASSWORD}
      - MARIADB_DATABASE=${MARIADB_DATABASE}
    command:
      - '--character-set-server=utf8mb4'
      - '--collation-server=utf8mb4_unicode_ci'
      - '--init-connect=SET NAMES utf8mb4'
    volumes:
      - mariadb_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mariadb-admin", "ping", "-h", "localhost", "-u", "root", "-p${MARIADB_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - moodle_network

  moodle:
    image: abstechnology/moodle-standard:5.0.1
    container_name: absi_moodle
    ports:
      - "80:8080"
      - "443:8443"
    environment:
      # Moodle Admin Configuration
      - MOODLE_USERNAME=${MOODLE_USERNAME}
      - MOODLE_PASSWORD=${MOODLE_PASSWORD}
      - MOODLE_EMAIL=${MOODLE_EMAIL}
      
      # Moodle Site Configuration
      - MOODLE_SITE_NAME=${MOODLE_SITE_NAME}
      - MOODLE_SITE_FULLNAME=${MOODLE_SITE_FULLNAME}
      - MOODLE_SITE_SHORTNAME=${MOODLE_SITE_SHORTNAME}
      - MOODLE_CRON_MINUTES=${MOODLE_CRON_MINUTES}
      
      # Database Configuration
      - MOODLE_DATABASE_TYPE=${MOODLE_DATABASE_TYPE}
      - MOODLE_DATABASE_HOST=${MOODLE_DATABASE_HOST}
      - MOODLE_DATABASE_PORT_NUMBER=${MOODLE_DATABASE_PORT_NUMBER}
      - MOODLE_DATABASE_USER=${MARIADB_USER}
      - MOODLE_DATABASE_PASSWORD=${MARIADB_PASSWORD}
      - MOODLE_DATABASE_NAME=${MARIADB_DATABASE}
      
      # PHP Configuration Limits
      - PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT}
      - PHP_MAX_INPUT_VARS=${PHP_MAX_INPUT_VARS}
      - PHP_MAX_FILE_UPLOADS=${PHP_MAX_FILE_UPLOADS}
      - PHP_POST_MAX_SIZE=${PHP_POST_MAX_SIZE}
      - PHP_UPLOAD_MAX_FILESIZE=${PHP_UPLOAD_MAX_FILESIZE}
      - PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME}
      
      # MariaDB Connection Configuration
      - MARIADB_HOST=${MOODLE_DATABASE_HOST}
      - MARIADB_PORT_NUMBER=${MOODLE_DATABASE_PORT_NUMBER}
      - MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
      - MARIADB_PASSWORD=${MARIADB_PASSWORD}
      
      # Proxy Configuration
      - MOODLE_REVERSEPROXY=${MOODLE_REVERSEPROXY}
      - MOODLE_SSLPROXY=${MOODLE_SSLPROXY}
      
    volumes:
      - ./data/moodle:/var/www/html
      - ./data/moodledata:/var/www/moodledata
    depends_on:
      mariadb:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/login/index.php"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    networks:
      - moodle_network

networks:
  moodle_network:
    driver: bridge

volumes:
  mariadb_data:
```

### 2. Create .env file

```bash
# Download environment template
curl -o .env https://raw.githubusercontent.com/abs-technology/moodle/main/env.example

# Or create manually:
```

```env
# ====================================================================
# ABSI TECHNOLOGY MOODLE - ENVIRONMENT CONFIGURATION
# ====================================================================

# Database Configuration
MARIADB_ROOT_PASSWORD=CHANGE_THIS_TO_STRONG_ROOT_PASSWORD
MARIADB_DATABASE=absi_moodle_db
MARIADB_USER=absi_moodle_user
MARIADB_PASSWORD=CHANGE_THIS_TO_STRONG_DB_PASSWORD

# Moodle Admin Configuration
MOODLE_USERNAME=absi_admin
MOODLE_PASSWORD=CHANGE_THIS_TO_STRONG_ADMIN_PASSWORD
MOODLE_EMAIL=admin@yourdomain.com

# Moodle Site Configuration
MOODLE_SITE_NAME=Absi Technology Moodle LMS®
MOODLE_SITE_FULLNAME=Absi Technology Learning Management System
MOODLE_SITE_SHORTNAME=ABSI-LMS
MOODLE_CRON_MINUTES=1
MOODLE_REVERSEPROXY=yes
MOODLE_SSLPROXY=yes

# Database Connection Configuration
MOODLE_DATABASE_TYPE=mariadb
MOODLE_DATABASE_HOST=mariadb
MOODLE_DATABASE_PORT_NUMBER=3306

# PHP Configuration Limits
PHP_MEMORY_LIMIT=512M
PHP_MAX_INPUT_VARS=5000
PHP_MAX_FILE_UPLOADS=200
PHP_POST_MAX_SIZE=2G
PHP_UPLOAD_MAX_FILESIZE=2G
PHP_MAX_EXECUTION_TIME=256
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

- **URL**: http://localhost or https://localhost
- **Admin**: Use credentials from `.env` file
- **Login**: http://localhost/login/

## 🔧 Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `MARIADB_ROOT_PASSWORD` | Database root password | `SecureRootPass123!` |
| `MARIADB_PASSWORD` | Database user password | `SecureDbPass123!` |
| `MOODLE_PASSWORD` | Admin user password | `AdminPass123!` |
| `MOODLE_EMAIL` | Admin email address | `admin@school.edu` |

### Database Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MARIADB_DATABASE` | `absi_moodle_db` | Database name |
| `MARIADB_USER` | `absi_moodle_user` | Database username |
| `MOODLE_DATABASE_HOST` | `mariadb` | Database hostname |
| `MOODLE_DATABASE_TYPE` | `mariadb` | Database type |
| `MOODLE_DATABASE_PORT_NUMBER` | `3306` | Database port |

### Site Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MOODLE_USERNAME` | `absi_admin` | Admin username |
| `MOODLE_SITE_NAME` | `Absi Technology Moodle LMS®` | Site display name |
| `MOODLE_SITE_FULLNAME` | `Absi Technology Learning Management System` | Site full name |
| `MOODLE_SITE_SHORTNAME` | `ABSI-LMS` | Site short name |
| `MOODLE_CRON_MINUTES` | `1` | Cron job interval |

### PHP Performance Tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_MEMORY_LIMIT` | `512M` | PHP memory limit |
| `PHP_MAX_INPUT_VARS` | `5000` | Max input variables |
| `PHP_MAX_FILE_UPLOADS` | `200` | Max file uploads |
| `PHP_POST_MAX_SIZE` | `2G` | Max POST request size |
| `PHP_UPLOAD_MAX_FILESIZE` | `2G` | Max upload file size |
| `PHP_MAX_EXECUTION_TIME` | `256` | Max execution time |

### Production Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `MOODLE_REVERSEPROXY` | `yes` | Enable reverse proxy support |
| `MOODLE_SSLPROXY` | `yes` | Enable SSL proxy support |

## 🔒 Security Best Practices

### Generate Strong Passwords

```bash
# Generate secure passwords
echo "MARIADB_ROOT_PASSWORD=$(openssl rand -base64 32)"
echo "MARIADB_PASSWORD=$(openssl rand -base64 24)"
echo "MOODLE_PASSWORD=$(openssl rand -base64 16)"
```

### Update .env file

```bash
# Edit with generated passwords
nano .env

# Set proper permissions
chmod 600 .env
```

## 🏗️ Production Setup

### For Load Balancer/Reverse Proxy

```env
# Already enabled by default in .env
MOODLE_REVERSEPROXY=yes
MOODLE_SSLPROXY=yes
```

### Performance Optimization

```env
# High performance settings in .env
PHP_MEMORY_LIMIT=1G
PHP_MAX_INPUT_VARS=10000
PHP_POST_MAX_SIZE=5G
PHP_UPLOAD_MAX_FILESIZE=5G
```

### Resource Limits

Add to docker-compose.yml:

```yaml
services:
  moodle:
    # ... existing config ...
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.5'
        reservations:
          memory: 1G
          cpus: '0.5'
```

## 🛠️ Management Commands

### View Logs

```bash
# All services
docker-compose logs

# Moodle only
docker-compose logs absi_moodle

# MariaDB only
docker-compose logs absi_mariadb

# Follow logs
docker-compose logs -f absi_moodle
```

### Container Management

```bash
# Stop services
docker-compose down

# Restart specific service
docker-compose restart absi_moodle

# Update images
docker-compose pull
docker-compose up -d
```

### Backup & Restore

```bash
# Database backup
docker-compose exec absi_mariadb mysqldump -u root -p${MARIADB_ROOT_PASSWORD} ${MARIADB_DATABASE} > backup.sql

# Restore database
docker-compose exec -T absi_mariadb mysql -u root -p${MARIADB_ROOT_PASSWORD} ${MARIADB_DATABASE} < backup.sql

# Backup moodle data
tar -czf moodledata-backup.tar.gz ./data/moodledata/
```

## 🐛 Troubleshooting

### Check Service Status

```bash
# Check container health
docker-compose ps

# View resource usage  
docker stats absi_moodle absi_mariadb

# Test database connection
docker-compose exec absi_moodle php -r "new PDO('mysql:host=mariadb;dbname=${MARIADB_DATABASE}', '${MARIADB_USER}', '${MARIADB_PASSWORD}');"
```

### Common Issues

**Services won't start:**
```bash
# Check .env file exists and has proper values
cat .env

# Check docker-compose syntax
docker-compose config
```

**Database connection failed:**
```bash
# Check database logs
docker-compose logs absi_mariadb

# Check database health
docker-compose exec absi_mariadb mariadb-admin ping -h localhost -u root -p${MARIADB_ROOT_PASSWORD}

# Restart database
docker-compose restart absi_mariadb
```

**File upload issues:**
- Increase `PHP_POST_MAX_SIZE` and `PHP_UPLOAD_MAX_FILESIZE` in `.env`
- Check disk space: `df -h`

**Access container shell:**
```bash
# Moodle container
docker-compose exec absi_moodle bash

# MariaDB container
docker-compose exec absi_mariadb bash
```

## 📋 Features

- ✅ **Moodle 5.0.1** - Latest stable version
- ✅ **PHP 8.4** with FPM and OPcache
- ✅ **Apache 2.4** with SSL support
- ✅ **MariaDB 11.7.2** - High performance database
- ✅ **Non-root container** - Security hardened
- ✅ **Environment variables** - Easy configuration
- ✅ **Health checks** - Built-in monitoring
- ✅ **Logging** - Container-friendly logging

## 📞 Support

- **GitHub Issues**: [Report Issues](https://github.com/abs-technology/moodle/issues)
- **Documentation**: [Moodle Docs](https://docs.moodle.org/)
- **Commercial Support**: support@absi.edu.vn

---

**Maintained by**: [Absi Technology](https://absi.edu.vn)  
**License**: MIT (Docker setup) / GPL v3+ (Moodle) 