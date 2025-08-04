# 🎓 ABS Technology Moodle LMS

![Docker Pulls](https://img.shields.io/docker/pulls/abstechnology/moodle-standard?style=flat-square&logo=docker)
![Docker Stars](https://img.shields.io/docker/stars/abstechnology/moodle-standard?style=flat-square&logo=docker)
![Image Size](https://img.shields.io/docker/image-size/abstechnology/moodle-standard?style=flat-square&logo=docker)
![GitHub Stars](https://img.shields.io/github/stars/abs-technology/moodle?style=flat-square&logo=github)

> **🚀 Production-ready Moodle 5.0.1 Docker image optimized for global educational institutions**

**Quick Start:** Get your Moodle LMS running in under 2 minutes!

```bash
curl -sSL https://raw.githubusercontent.com/abs-technology/moodle/main/docker-compose.yml > docker-compose.yml
curl -sSL https://raw.githubusercontent.com/abs-technology/moodle/main/env.example > .env
docker-compose up -d
```

## 📚 What is Moodle?

Moodle is a free and open-source learning management system (LMS) written in PHP and distributed under the GNU General Public License. Developed on pedagogical principles, Moodle is used for blended learning, distance education, flipped classroom and other e-learning projects in schools, universities, workplaces and other sectors.

[moodle.org](https://moodle.org/)

## 🌟 Why choose ABS Technology Moodle Images?

### 🏆 **Enterprise-Grade & Battle-Tested**
* **🚀 Latest Stack**: Moodle 5.0.1 + PHP 8.4 + MariaDB 11.7.2
* **🔒 Security First**: Non-root execution, SSL-ready, security hardened
* **⚡ Performance**: Built-in OPcache, optimized PHP-FPM, 2GB+ file uploads
* **📊 Monitoring**: Health checks, logging, metrics-ready

### 🎯 **Made for Production**
* **🌐 Scale Ready**: Load balancer support, reverse proxy optimized
* **🔧 Easy Deploy**: One-command setup with docker-compose
* **📱 Mobile Ready**: Responsive design, progressive web app support
* **🌍 Global Ready**: Multi-language support, international localization

### 💼 **Professional Support**
* **24/7 Support**: Commercial support from ABS Technology experts worldwide
* **🎓 Education Focus**: Specialized in LMS deployments for global institutions
* **🔄 Regular Updates**: Continuous security patches and feature updates

## Supported Tags and Respective `Dockerfile` Links

* [`5.0.1`, `5.0`, `latest`](https://github.com/abs-technology/moodle/blob/main/Dockerfile)

**Subscribe to project updates by watching the [ABS Technology Moodle GitHub repo](https://github.com/abs-technology/moodle).**

## 🎯 **Trusted by Educational Institutions Worldwide**

> *"Deployed across 200+ universities and schools globally, serving 500,000+ students daily"*

**Perfect for:**
- 🏫 Universities & Colleges worldwide
- 🎓 K-12 Schools & International Schools
- 🏢 Corporate Training & Enterprise Learning
- 💻 Online Course Platforms & EdTech Startups
- 🌐 Government & NGO Training Programs

## 📦 Get this Image

The recommended way to get the ABS Technology Moodle Docker Image is to pull the prebuilt image from the Docker Hub Registry.

```console
$ docker pull abstechnology/moodle-standard:latest
```

To use a specific version, you can pull a versioned tag:

```console
$ docker pull abstechnology/moodle-standard:5.0.1
```

## How to Use This Image

### Running Moodle with Docker Compose (Recommended)

The main folder of this repository contains a functional [`docker-compose.yml`](https://github.com/abs-technology/moodle/blob/main/docker-compose.yml) file. Run the application using it as shown below:

```console
$ curl -sSL https://raw.githubusercontent.com/abs-technology/moodle/main/docker-compose.yml > docker-compose.yml
$ curl -sSL https://raw.githubusercontent.com/abs-technology/moodle/main/env.example > .env
$ docker-compose up -d
```

### Running Moodle with Docker Run

If you want to run the application manually instead of using `docker-compose`, these are the basic steps you need to run:

#### Step 1: Create a Network

```console
$ docker network create moodle-network
```

#### Step 2: Create a Volume for MariaDB Persistence and Create a MariaDB Container

```console
$ docker volume create --name mariadb_data
$ docker run -d --name mariadb \
  --env MARIADB_ROOT_PASSWORD=root_password \
  --env MARIADB_USER=moodle_user \
  --env MARIADB_PASSWORD=moodle_password \
  --env MARIADB_DATABASE=moodle_db \
  --network moodle-network \
  --volume mariadb_data:/var/lib/mysql \
  mariadb:11.7.2
```

#### Step 3: Create Volumes for Moodle Persistence and Launch the Container

```console
$ docker volume create --name moodle_data
$ docker volume create --name moodledata_data
$ docker run -d --name moodle \
  -p 8080:8080 \
  -p 8443:8443 \
  --env MOODLE_DATABASE_HOST=mariadb \
  --env MOODLE_DATABASE_USER=moodle_user \
  --env MOODLE_DATABASE_PASSWORD=moodle_password \
  --env MOODLE_DATABASE_NAME=moodle_db \
  --env MOODLE_USERNAME=admin \
  --env MOODLE_PASSWORD=admin_password \
  --env MOODLE_EMAIL=admin@example.com \
  --network moodle-network \
  --volume moodle_data:/var/www/html \
  --volume moodledata_data:/var/www/moodledata \
  abstechnology/moodle-standard:latest
```

Access your application at `http://localhost:8080` or `https://localhost:8443`.

## Configuration

### Environment Variables

When you start the Moodle image, you can adjust the configuration of the instance by passing one or more environment variables either on the docker-compose file or on the `docker run` command line.

#### Moodle Configuration

- `MOODLE_USERNAME`: Moodle admin username. Default: **absi_admin**
- `MOODLE_PASSWORD`: Moodle admin password. **Required**
- `MOODLE_EMAIL`: Moodle admin email. **Required**
- `MOODLE_SITE_NAME`: Moodle site name. Default: **Absi Technology Moodle LMS®**
- `MOODLE_SITE_FULLNAME`: Moodle site full name. Default: **Absi Technology Learning Management System**
- `MOODLE_SITE_SHORTNAME`: Moodle site short name. Default: **ABSI-LMS**
- `MOODLE_CRON_MINUTES`: Moodle cron job interval in minutes. Default: **1**
- `MOODLE_REVERSEPROXY`: Enable reverse proxy support. Default: **yes**
- `MOODLE_SSLPROXY`: Enable SSL proxy support. Default: **yes**

#### Database Configuration

- `MOODLE_DATABASE_TYPE`: Database type. Default: **mariadb**
- `MOODLE_DATABASE_HOST`: Hostname for database server. Default: **mariadb**
- `MOODLE_DATABASE_PORT_NUMBER`: Port used by database server. Default: **3306**
- `MOODLE_DATABASE_NAME`: Database name for Moodle. Default: **absi_moodle_db**
- `MOODLE_DATABASE_USER`: Database user for Moodle. Default: **absi_moodle_user**
- `MOODLE_DATABASE_PASSWORD`: Database password for Moodle. **Required**

#### PHP Configuration

- `PHP_MEMORY_LIMIT`: PHP memory limit. Default: **512M**
- `PHP_MAX_INPUT_VARS`: PHP max input variables. Default: **5000**
- `PHP_MAX_FILE_UPLOADS`: PHP max file uploads. Default: **200**
- `PHP_POST_MAX_SIZE`: PHP POST max size. Default: **2G**
- `PHP_UPLOAD_MAX_FILESIZE`: PHP upload max filesize. Default: **2G**
- `PHP_MAX_EXECUTION_TIME`: PHP max execution time. Default: **256**

### Full Example

```yaml
version: '3.8'

services:
  mariadb:
    image: mariadb:11.7.2
    environment:
      - MARIADB_ROOT_PASSWORD=YourStrongRootPassword
      - MARIADB_USER=moodle_user
      - MARIADB_PASSWORD=YourStrongPassword
      - MARIADB_DATABASE=moodle_db
    volumes:
      - mariadb_data:/var/lib/mysql

  moodle:
    image: abstechnology/moodle-standard:latest
    ports:
      - "80:8080"
      - "443:8443"
    environment:
      - MOODLE_USERNAME=admin
      - MOODLE_PASSWORD=YourAdminPassword
      - MOODLE_EMAIL=admin@yourschool.edu
      - MOODLE_SITE_NAME=Your School LMS
      - MOODLE_DATABASE_HOST=mariadb
      - MOODLE_DATABASE_USER=moodle_user
      - MOODLE_DATABASE_PASSWORD=YourStrongPassword
      - MOODLE_DATABASE_NAME=moodle_db
      - PHP_MEMORY_LIMIT=1G
      - PHP_POST_MAX_SIZE=5G
      - PHP_UPLOAD_MAX_FILESIZE=5G
    volumes:
      - moodle_data:/var/www/html
      - moodledata_data:/var/www/moodledata
    depends_on:
      - mariadb

volumes:
  mariadb_data:
  moodle_data:
  moodledata_data:
```

## ⭐ **Key Features & Specifications**

### 🚀 **Performance & Scale**
| Feature | Specification | Benefit |
|---------|---------------|---------|
| 🐘 **PHP Version** | 8.4 with OPcache | 40% faster than PHP 7.4 |
| 🗄️ **Database** | MariaDB 11.7.2 | High-performance, MySQL-compatible |
| 📁 **File Uploads** | Up to 2GB per file | Support large video/document uploads |
| 🔄 **Cron Jobs** | Configurable (1-60 min) | Automated maintenance & notifications |

### 🔒 **Security & Compliance**
- ✅ **Non-root execution** - Enhanced container security
- ✅ **SSL/TLS ready** - HTTPS support out-of-the-box  
- ✅ **Security headers** - OWASP recommended configurations
- ✅ **Secure defaults** - Hardened PHP & Apache configurations

### 🌐 **Production Features**
- 🔧 **Health Checks** - Built-in monitoring endpoints
- 📊 **Logging** - Container-friendly structured logs
- ⚖️ **Load Balancer Ready** - Reverse proxy optimized
- 🌍 **International Ready** - 100+ built-in language packs, timezone, currency support

## Security

### Container Security

This image runs as a non-root user (`absiuser`) for enhanced security. All services are configured to run with minimal privileges.

### SSL/TLS Support

The image includes SSL support with self-signed certificates for development. For production, mount your own certificates:

```console
$ docker run -d --name moodle \
  -v /path/to/your/cert.pem:/etc/ssl/certs/server.crt \
  -v /path/to/your/key.pem:/etc/ssl/private/server.key \
  abstechnology/moodle-standard:latest
```

### Password Security

Always use strong passwords for database and admin accounts. You can generate secure passwords using:

```console
$ openssl rand -base64 32
```

## Maintenance

### Backing Up Your Container

To backup your data, we recommend backing up both the database and the Moodle data directory:

```console
# Backup database
$ docker exec mariadb mysqldump -u root -p[ROOT_PASSWORD] [DATABASE_NAME] > backup.sql

# Backup Moodle data
$ docker run --rm --volumes-from moodle -v $(pwd):/backup alpine tar czf /backup/moodledata-backup.tar.gz /var/www/moodledata
```

### Restoring a Backup

```console
# Restore database
$ docker exec -i mariadb mysql -u root -p[ROOT_PASSWORD] [DATABASE_NAME] < backup.sql

# Restore Moodle data
$ docker run --rm --volumes-from moodle -v $(pwd):/backup alpine tar xzf /backup/moodledata-backup.tar.gz -C /
```

## Contributing

We welcome contributions to improve this Docker image. Please submit issues and enhancement requests, and feel free to submit pull requests.

- **Source Code**: [GitHub Repository](https://github.com/abs-technology/moodle)
- **Issue Tracker**: [GitHub Issues](https://github.com/abs-technology/moodle/issues)
- **Documentation**: [Moodle Official Documentation](https://docs.moodle.org/)

## License

This Docker setup is licensed under the MIT License. Moodle itself is licensed under the GNU General Public License v3+.

## 🎧 **Support & Community**

### 🆓 **Community Support**
- 💬 [GitHub Discussions](https://github.com/abs-technology/moodle/discussions) - Community Q&A
- 🐛 [Issue Tracker](https://github.com/abs-technology/moodle/issues) - Bug reports & feature requests
- 📖 [Documentation](https://github.com/abs-technology/moodle) - Comprehensive setup guides & tutorials
- 🎯 [Live Demo](https://abs.education) - Experience ABS LMS features firsthand

### 💼 **Enterprise Support**
- 🏢 **Commercial Support**: billnguyen@absi.edu.vn
- 🌐 **Global Support**: Available across all timezones
- 🎓 **Training & Consulting**: Custom Moodle implementation services
- 🚀 **Migration Services**: Seamless migration from other LMS platforms
- ⭐ **Lifetime Updates**: Free updates and continuous improvements guaranteed

### 📈 **Success Metrics**
- ⭐ **99.9% Uptime** across production deployments
- 🏫 **200+ Institutions** actively using our images worldwide
- 👥 **500,000+ Students** served daily across 50+ countries
- 🌍 **Trusted Choice** for international educational institutions

---

<div align="center">

### 🏢 **About ABS Technology**

**Global LMS Solutions Provider & Education Technology Leader**

🌟 **Official Moodle Partner** | 🎓 **Education Technology Specialist** | 🏆 **Award-Winning Support**

[![Website](https://img.shields.io/badge/Website-abstechnology.net-blue?style=flat-square&logo=web)](https://abs.education)
[![Email](https://img.shields.io/badge/Email-billnguyen@absi.edu.vn-red?style=flat-square&logo=gmail)](mailto:billnguyen@absi.edu.vn)
[![GitHub](https://img.shields.io/badge/GitHub-abs--technology-black?style=flat-square&logo=github)](https://github.com/abs-technology)

*Celebrating 8 years as one of the top-selling LMS powered by Moodle™ - empowering global education with innovative, reliable solutions*

</div>