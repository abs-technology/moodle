# ABS Technology Moodle image

Docker image `abstechnology/moodle-standard` for Moodle LMS. Moodle core is downloaded at build time from packaging.moodle.org. This git tree is the container and deploy layer, licensed **GPL-3.0-or-later**.

| Pin | Value |
|-----|--------|
| Moodle | **5.3.0** |
| Image | **`abstechnology/moodle-standard:5.3.0-r5`** |
| PHP | **8.4.27** |
| Base | **`debian:13-slim`** (digest in [`versions.lock`](versions.lock)) |
| Compose database | **MariaDB 11.8.9** |

[`versions.lock`](versions.lock) is the source of truth. Live VMs keep the image they were created with.

Docs: [docs/WHAT-WE-SHIP.md](docs/WHAT-WE-SHIP.md) · [docs/SUPPORT-MATRIX.md](docs/SUPPORT-MATRIX.md) · [SECURITY.md](SECURITY.md) · [docs/RUNBOOK.md](docs/RUNBOOK.md) · [CONTRIBUTING.md](CONTRIBUTING.md)

GKE (Cloud SQL MySQL 8.4, Global ALB) is a **separate** stack: [`gke-moodle/`](gke-moodle/README.md). It does not use `terraform/` VM deployments.

## Quick start

```bash
curl -sSL https://raw.githubusercontent.com/abs-technology/moodle/main/docker-compose.yml > docker-compose.yml
curl -sSL https://raw.githubusercontent.com/abs-technology/moodle/main/env.example > .env
mkdir -p data/moodle data/moodledata
chown -R 1000:1000 data/moodle data/moodledata
docker compose up -d
```

<div align="center">

### [🌐 **Live Demo**](https://abs.education) • [📚 **Documentation**](https://abs.education/mod/page/view.php?id=410) • [💬 **Support**](https://abs.education/mod/page/view.php?id=410)

</div>

---

## 📚 About Moodle

<div align="center">

<a href="https://moodle.org" target="_blank">
  <img src="https://raw.githubusercontent.com/moodle/moodle/main/.github/moodlelogo.svg" alt="Moodle Logo" width="400">
</a>

**The World's Open Source Learning Platform**

</div>

<table>
<tr>
<td width="50%">

### 🎯 **What is Moodle?**

[**Moodle**](https://moodle.org) is the world's most trusted open-source learning management system, empowering educators worldwide to create effective online learning experiences.

**🌍 Global Impact:**
- **300+ million users** worldwide
- **250,000+ education sites** in 240+ countries  
- **Available in 120+ languages**
- **Trusted by**: Harvard, MIT, Shell, Microsoft

</td>
<td width="50%">

### 🚀 **Key Features**

**Learning Modes:**
- 🎓 **Blended Learning** - Online + face-to-face
- 🌐 **Distance Education** - Fully online courses  
- 🔄 **Flipped Classroom** - Interactive learning
- 📚 **Corporate Training** - Professional development

**Built For:**
- 🏫 Universities & Schools
- 🏢 Corporate Training
- 🎯 Custom E-Learning Solutions

</td>
</tr>
</table>

### 📖 **Official Resources**

| Resource | Description | Link |
|----------|-------------|------|
| 📚 **User Guide** | Complete documentation for educators | [docs.moodle.org](https://docs.moodle.org/) |
| 🛠️ **Developer Docs** | Technical documentation & APIs | [moodledev.io](https://moodledev.io) |
| 🧪 **Live Demo** | Try Moodle without installation | [sandbox.moodledemo.net](https://sandbox.moodledemo.net/) |
| 👥 **Community** | Join global educators network | [moodle.org](https://moodle.org) |
| 🎪 **Events** | Moodle conferences worldwide | [Moodle Moots](https://moodle.com/events/mootglobal/) |
| 🤝 **Association** | Official user association | [moodleassociation.org](https://moodleassociation.org/) |

**License**: [GNU General Public License v3.0](https://moodledev.io/general/license)


## 🌟 Why Choose ABS Technology Moodle?

<div align="center">

### *The Ultimate Moodle Docker Solution for Modern Education*

</div>

<table>
<tr>
<td width="33%" align="center">

### 🏆 **Enterprise-Grade**
<img src="https://img.shields.io/badge/Production-Ready-success?style=for-the-badge" alt="Production Ready"/>

**Latest Technology Stack**
- 🚀 **Moodle 5.3.0** - Current LTS pin (`5.3.0-r5` image, Debian 13)
- 🐘 **PHP 8.4** - Performance boost
- 🗄️ **MariaDB 11.8.9** - Compose database pin
- 🔒 **Security Hardened** - Non-root execution · Scout gate on push
- ⚡ **OPcache Enabled** - 3x faster performance

</td>
<td width="33%" align="center">

### 🎯 **Production-Ready**  
<img src="https://img.shields.io/badge/Scale-Ready-blue?style=for-the-badge" alt="Scale Ready"/>

**Built for High-Traffic**
- 🌐 **Load Balancer** - Handle thousands of users
- 🔧 **One-Command Deploy** - `docker compose up`
- 📱 **Mobile Optimized** - PWA support
- 🌍 **Multi-Language** - 120+ languages
- 📊 **Health Monitoring** - Built-in checks

</td>
<td width="33%" align="center">

### 💼 **[Professional Support](https://abs.education/mod/page/view.php?id=410)**
<img src="https://img.shields.io/badge/24/7-Support-orange?style=for-the-badge" alt="24/7 Support"/>

**Expert Assistance**
- 🎓 **Education Specialists** - LMS experts  
- 🔄 **Regular Updates** - Security patches
- 🌍 **Global Support** - Worldwide coverage
- 📞 **[Commercial Support](https://abs.education/mod/page/view.php?id=410)** - Enterprise SLA
- 🛠️ **Custom Solutions** - Tailored deployments

</td>
</tr>
</table>

---

### 🚀 **Performance Features**

<div align="center">

<table>
<tr>
<td width="50%" align="center">

### ⚡ **Speed Optimizations**
- **OPcache Enabled** - PHP opcode caching
- **Optimized PHP-FPM** - Better memory management
- **MariaDB Tuning** - Database performance tweaks
- **Apache/Nginx Ready** - Web server optimizations
- **Gzip Compression** - Reduced bandwidth usage

</td>
<td width="50%" align="center">

### 📈 **Scalability Features**
- **Large File Support** - Up to 2GB uploads
- **Memory Efficient** - Optimized PHP settings
- **Load Balancer Ready** - Multi-instance support
- **Caching Systems** - Redis/Memcached compatible
- **CDN Integration** - Static asset optimization

</td>
</tr>
</table>

**🎯 Built for high-traffic educational environments**

</div>

---

### 🎯 **Perfect For**

<table>
<tr>
<td width="25%" align="center">

### 🏫 **Universities**
- Large student populations
- Multi-campus deployments  
- Integration requirements
- Scalability needs

</td>
<td width="25%" align="center">

### 🎓 **Schools**
- K-12 education
- Teacher training
- Parent portals
- Student assessments

</td>
<td width="25%" align="center">

### 🏢 **Corporations**  
- Employee training
- Compliance courses
- Certification programs
- Skills development

</td>
<td width="25%" align="center">

### 🌐 **Organizations**
- Non-profit training
- Government education
- Healthcare learning
- Professional development

</td>
</tr>
</table>

## Supported Tags and Respective `Dockerfile` Links

* [`5.3.0-r5`](https://github.com/abs-technology/moodle/blob/main/Dockerfile) — current image. `5.3.0`, `5.3.0-r1`, `5.3.0-r2`, `5.3.0-r3` and `5.3.0-r4` stay published. `latest` was not moved.

Pinned in [`versions.lock`](https://github.com/abs-technology/moodle/blob/main/versions.lock): Moodle **5.3.0** from [packaging.moodle.org stable503](https://packaging.moodle.org/stable503/moodle-5.3.tgz), PHP **8.4.27**, base **`debian:13-slim`**, Docker tag **`5.3.0-r5`**.

Multi-arch Hub image (`linux/amd64` + `linux/arm64`) is published by GitHub Actions on tag `v<DOCKER_TAG>`. Laptop `make push` is break-glass. Default **`ATTESTATIONS=none`** on the Hub image (no provenance/SBOM attach) so Marketplace does not flag BuildKit Go CVEs. A separate SBOM file is attached to the GitHub Release. See [`docs/SECURITY-EXCEPTIONS.md`](docs/SECURITY-EXCEPTIONS.md), [`docs/RUNBOOK.md`](docs/RUNBOOK.md), and [`docs/SUPPORT-MATRIX.md`](docs/SUPPORT-MATRIX.md).

**Subscribe to project updates by watching the [ABS Technology Moodle GitHub repo](https://github.com/abs-technology/moodle).**

## 📦 Get this Image

The recommended way to get the ABS Technology Moodle Docker Image is to pull the prebuilt image from the Docker Hub Registry.

```console
$ docker pull abstechnology/moodle-standard:5.3.0-r5
```

## How to Use This Image

### Running Moodle with Docker Compose (Recommended)

The main folder of this repository contains a functional [`docker-compose.yml`](https://github.com/abs-technology/moodle/blob/main/docker-compose.yml) file. Run the application using it as shown below:

```console
$ curl -sSL https://raw.githubusercontent.com/abs-technology/moodle/main/docker-compose.yml > docker-compose.yml
$ curl -sSL https://raw.githubusercontent.com/abs-technology/moodle/main/env.example > .env
$ mkdir -p data/moodle data/moodledata
$ docker compose up -d
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
  mariadb:11.8.9
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
  abstechnology/moodle-standard:5.3.0-r5
```

Access your application at `http://localhost:8080` or `https://localhost:8443`.

## Configuration

### Environment Variables

When you start the Moodle image, you can adjust the configuration of the instance by passing one or more environment variables either on the docker-compose file or on the `docker run` command line.

#### Moodle Configuration

- `MOODLE_USERNAME`: Moodle admin username. Read on first install only. Default: **admin**. Later restarts do not rename it.
- `MOODLE_PASSWORD`: Moodle admin password. Read on first install only. **Required**. Later restarts do not reset it.

Marketplace, GCP and AWS VMs are unchanged: their bootstrap still writes `MOODLE_USERNAME=admin` and the generated password. A custom username applies only when that `.env` sets one before the first install.
- `MOODLE_EMAIL`: Moodle admin email. **Required**
- `MOODLE_SITE_NAME`: Moodle site name. Default: **ABS Technology Moodle LMS®**
- `MOODLE_SITE_FULLNAME`: Moodle site full name. Default: **Absi Technology Learning Management System**
- `MOODLE_SITE_SHORTNAME`: Moodle site short name. Default: **ABS-LMS**
- `MOODLE_CRON_MINUTES`: Moodle cron job interval in minutes. Default: **1**
- `MOODLE_WWWROOT`: Public site URL, identical on every node. Default: **empty** (guessed per request)
- `MOODLE_SSLPROXY`: Proxy terminates TLS and forwards http. Default: **no** (set **yes** behind Traefik/Nginx/CloudFlare/GCP/AWS)
- `MOODLE_REVERSEPROXY`: Only for proxies that rewrite the `Host` header. Default: **no** — keep it **no** for Traefik, AWS ALB and GCP
- `MOODLE_CLUSTER`: Shared DB sessions + node-local cache for 2+ nodes. Default: **no**

Behind a TLS-terminating proxy set `MOODLE_WWWROOT` and `MOODLE_SSLPROXY=yes`,
and leave `MOODLE_REVERSEPROXY=no`: Moodle 5.x rejects `reverseproxy` when the
proxy forwards the original `Host`. Load balancers must probe `/readyz`, never
`/login/index.php`. Full guide: [docs/LOAD-BALANCING.md](docs/LOAD-BALANCING.md).

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
- `PHP_MAX_EXECUTION_TIME`: PHP max execution time. Default: **600**

### Full Example

```yaml
services:
  mariadb:
    image: mariadb:11.8.9
    container_name: abs-mariadb
    restart: unless-stopped
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
    image: abstechnology/moodle-standard:5.3.0-r5
    container_name: abs-moodle
    restart: unless-stopped
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
      
      # Proxy Configuration (see docs/LOAD-BALANCING.md)
      - MOODLE_WWWROOT=${MOODLE_WWWROOT:-}
      - MOODLE_SSLPROXY=${MOODLE_SSLPROXY}
      - MOODLE_REVERSEPROXY=${MOODLE_REVERSEPROXY}
      - MOODLE_CLUSTER=${MOODLE_CLUSTER:-no}

      # Upgrade behavior (see env.example for details)
      - MOODLE_AUTO_DB_UPGRADE=${MOODLE_AUTO_DB_UPGRADE:-no}
      - MOODLE_BACKUP_DIR=${MOODLE_BACKUP_DIR:-/var/www/moodle-backups}
      - MOODLE_UPGRADE_RETENTION=${MOODLE_UPGRADE_RETENTION:-5}

    volumes:
      - ./data/moodle:/var/www/html
      - ./data/moodledata:/var/www/moodledata
      - ./data/moodle-backups:/var/www/moodle-backups
    depends_on:
      mariadb:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-fsS", "-o", "/dev/null", "http://localhost:8080/healthz"]
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

## ⭐ **Key Features & Specifications**

### 🚀 **Performance & Scale**
| Feature | Specification | Benefit |
|---------|---------------|---------|
| 🐘 **PHP Version** | 8.4 with OPcache | Current Moodle 5.3 runtime |
| 🗄️ **Database** | MariaDB 11.8.9 (compose) | High-performance, MySQL-compatible |
| 📦 **Image tag** | `5.3.0-r5` | Marketplace-oriented pin (see `versions.lock`) |
| 📁 **File Uploads** | Up to 2GB per file | Support large video/document uploads |
| 🔄 **Cron Jobs** | Configurable (1-60 min) | Automated maintenance & notifications |

### 🔒 **Security & Compliance**
- ✅ **Non-root execution** - Enhanced container security
- ✅ **SSL/TLS ready** - HTTPS support out-of-the-box  
- ✅ **Security headers** - OWASP recommended configurations
- ✅ **Secure defaults** - Hardened PHP & Apache configurations
- ✅ **Scout gate on both platforms** - Fixable Critical/High before Hub push
- ✅ **Composer security pins** - AWS SDK / Guzzle / jmespath updates beyond Moodle lockfile

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
  abstechnology/moodle-standard:5.3.0-r5
```

### Password Security

Always use strong passwords for database and admin accounts. You can generate secure passwords using:

```console
$ openssl rand -base64 32
```

Known Scout / Marketplace exceptions and attestation policy: [`docs/SECURITY-EXCEPTIONS.md`](docs/SECURITY-EXCEPTIONS.md).

## Building & releasing (maintainers)

Pins live in [`versions.lock`](versions.lock). Publish is GitHub Actions on tag `v<DOCKER_TAG>` ([`docs/RUNBOOK.md`](docs/RUNBOOK.md)).

```console
$ ./scripts/git-hooks/install.sh   # strip banned AI attribution trailers
$ ./scripts/verify-build-manifest.sh
$ make build                       # native arch smoke build
$ ./scripts/smoke-image.sh
# Tag v<DOCKER_TAG> and push. Actions Scouts both platforms, pushes Hub, signs, attaches SBOM.
# make push is break-glass only. Do not retag latest.
```

Release notes are required for every new image tag — see [`docs/RELEASE-NOTES-POLICY.md`](docs/RELEASE-NOTES-POLICY.md) and [`AGENTS.md`](AGENTS.md).

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
- **Maintainer policies**: [`AGENTS.md`](AGENTS.md) · [`docs/RELEASE-NOTES-POLICY.md`](docs/RELEASE-NOTES-POLICY.md) · [`docs/NO-AGENT-ATTRIBUTION.md`](docs/NO-AGENT-ATTRIBUTION.md)
- **Documentation**: [Moodle Official Documentation](https://docs.moodle.org/)

Do not commit IDE folders such as `.cursor/` — they are gitignored.

## License

This repository (image and deploy layer) is licensed under **GPL-3.0-or-later**, same family as Moodle LMS. Moodle core is not in git; the build downloads the pinned tarball from packaging.moodle.org. See [`LICENSE`](LICENSE).

## 🎧 **Support & Community**

### 🆓 **Community Support**
- 💬 [GitHub Discussions](https://github.com/abs-technology/moodle/discussions) - Community Q&A
- 🐛 [Issue Tracker](https://github.com/abs-technology/moodle/issues) - Bug reports & feature requests
- 📖 [Documentation](https://github.com/abs-technology/moodle) - Comprehensive setup guides & tutorials
- 🎯 [Live Demo](https://abs.education) - Experience ABS LMS features firsthand

### 💼 **Enterprise Support**
- 🏢 **Commercial Support**: [Professional Services](https://abs.education/mod/page/view.php?id=410) | billnguyen@absi.edu.vn
- 🌐 **Global Support**: Available across all timezones
- 🎓 **Training & Consulting**: Custom Moodle implementation services
- 🚀 **Migration Services**: Seamless migration from other LMS platforms
- ⭐ **Lifetime Updates**: Free updates and continuous improvements guaranteed

---

## 🚀 Ready to Get Started?

<div align="center">

<table>
<tr>
<td align="center" width="33%">

### 🎯 **Quick Start**
Perfect for trying out

[![Deploy Now](https://img.shields.io/badge/🚀_Deploy_Now-success?style=for-the-badge&logoColor=white)](https://github.com/abs-technology/moodle/blob/main/README.md#-quick-start)

*One command deployment*

</td>
<td align="center" width="33%">

### 🏢 **Enterprise**  
Production-ready solution

[![Contact Sales](https://img.shields.io/badge/💼_Contact_Sales-blue?style=for-the-badge&logoColor=white)](https://abs.education/mod/page/view.php?id=410)

*Custom deployment & support*

</td>
<td align="center" width="33%">

### 🤝 **Community**
Join our community

[![Join Community](https://img.shields.io/badge/👥_Join_Community-orange?style=for-the-badge&logoColor=white)](https://github.com/abs-technology/moodle/discussions)

*Get help & share ideas*

</td>
</tr>
</table>

</div>

## 🏢 **About ABS Technology**

<div align="center">

**Global LMS Solutions Provider & Education Technology Leader**

🌟 **Official Google Cloud Partner** | 🎓 **Education Technology Specialist** | 🏆 **Award-Winning Support**

[![Website](https://img.shields.io/badge/Website-https://abs.education-blue?style=flat-square&logo=web)](https://abs.education)
[![Email](https://img.shields.io/badge/Email-billnguyen@absi.edu.vn-red?style=flat-square&logo=gmail)](mailto:billnguyen@absi.edu.vn)
[![GitHub](https://img.shields.io/badge/GitHub-abs--technology-black?style=flat-square&logo=github)](https://github.com/abs-technology)
[![Phone](https://img.shields.io/badge/Phone-+84_933_688_088-green?style=flat-square&logo=phone)](tel:+84933688088)
[![Location](https://img.shields.io/badge/Location-Ho_Chi_Minh_City-orange?style=flat-square&logo=googlemaps)](https://maps.app.goo.gl/APfMEmnyD1iZG15TA)

*Celebrating 8 years as one of the top-selling LMS powered by Moodle™ - empowering global education with innovative, reliable solutions*

</div>

---

<div align="center">

### 🌟 **Star us on GitHub if this helped you!**

<a href="https://github.com/abs-technology/moodle">
 <img src="https://img.shields.io/github/stars/abs-technology/moodle?style=for-the-badge&logo=github&logoColor=white&color=FFD700" alt="GitHub Stars"/>
</a>
<a href="https://github.com/abs-technology/moodle/fork">
 <img src="https://img.shields.io/github/forks/abs-technology/moodle?style=for-the-badge&logo=github&logoColor=white&color=32CD32" alt="GitHub Forks"/>
</a>
<a href="https://github.com/abs-technology/moodle/issues">
 <img src="https://img.shields.io/github/issues/abs-technology/moodle?style=for-the-badge&logo=github&logoColor=white&color=FF6B6B" alt="GitHub Issues"/>
</a>


</div>

---

<div align="center">
<sub><strong>Built with ❤️ by ABS Technology for the global education community</strong></sub><br/>
<sub>Licensed under <a href="https://github.com/abs-technology/moodle/blob/main/LICENSE">GPL v3.0</a> • <a href="https://abs.education">abs.education</a> • <a href="https://abs.education/mod/page/view.php?id=410">Professional Services</a></sub>
</div>