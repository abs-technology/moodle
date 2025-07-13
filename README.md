# Moodle LMS User Guide - Absi Technology

A complete Moodle Learning Management System packaged with Docker, easy to deploy and use for schools and enterprises.

## 🎓 Introduction

**Absi Technology Moodle LMS** is a complete e-learning solution, ready to use with:

- **Moodle 5.0.1** - Latest version with full features
- **User-friendly interface** - Easy to use for teachers and students
- **Quick deployment** - Get a complete system in just 10 minutes
- **High security** - Optimized for production environments
- **Automation** - Automatic backup, maintenance, cron jobs

## 🚀 Quick Start

### System Requirements

- **Computer/Server** with Docker installed
- **RAM**: Minimum 4GB (recommended 8GB+)
- **Storage**: 20GB free space (for system and data)
- **Internet**: For downloading and updates

### Step 1: Download and Prepare

```bash
# Download source code
git clone <repository-url>
cd absi-tech-moodle

# Copy configuration template
cp env.example .env
```

### Step 2: Basic Configuration

Open the `.env` file and adjust basic information:

```bash
# School/Organization information
MOODLE_SITE_NAME=Absi Technology 
MOODLE_SITE_FULLNAME=Absi Technology Learning Management System
MOODLE_SITE_SHORTNAME=ABSI

# Administrator account
MOODLE_USERNAME=admin
MOODLE_PASSWORD=StrongPassword123!
MOODLE_EMAIL=admin@absi-school.edu

# Database passwords (create strong passwords)
MARIADB_ROOT_PASSWORD=DatabaseRootPassword123!
MARIADB_PASSWORD=DatabaseMoodlePassword456!
```

### Step 3: Start the System

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs to monitor installation process
docker-compose logs -f moodle
```

### Step 4: Access Moodle

After successful startup (about 2-3 minutes):

- **Website**: http://localhost (or your server IP)
- **HTTPS**: https://localhost (self-signed certificate)
- **Login**: Use `MOODLE_USERNAME` and `MOODLE_PASSWORD` from `.env` file

## 📚 User Guide

### Administrator

#### First Login
1. Access the Moodle website
2. Click "Login" in the top right corner
3. Enter the configured admin account
4. Go to **Site administration** for configuration

#### Create New Course
1. Go to **Site administration** → **Courses** → **Manage courses and categories**
2. Click **Create new course**
3. Fill in information:
   - **Course full name**: e.g., "Mathematics 12A1"
   - **Course short name**: e.g., "MATH12A1"
   - **Category**: Choose or create appropriate category
4. **Save and display**

#### Create Teacher Account
1. **Site administration** → **Users** → **Accounts**
2. **Add a new user**
3. Fill in basic information and choose appropriate **Permissions**
4. Assign teacher to course: go to course → **Participants** → **Enrol users**

#### Configure Email
1. **Site administration** → **Server** → **Email** → **Outgoing mail configuration**
2. Configure SMTP server for email notifications
3. Test email sending to ensure functionality

### Teacher

#### Add Lesson Content
1. Enter assigned course
2. **Turn editing on** (button in top right)
3. **Add an activity or resource**
4. Choose content type:
   - **File**: Upload PDF, Word, PowerPoint documents
   - **Page**: Create HTML content directly
   - **URL**: Link to external websites
   - **Video**: Embed YouTube videos or upload videos

#### Create Quiz
1. **Add activity** → **Quiz**
2. Configure:
   - **Open/Close times**: When students can take the quiz
   - **Time limit**: How long to complete
   - **Attempts allowed**: How many retries allowed
3. **Add questions** from question bank or create new ones

#### Grading and Feedback
1. Go to **Gradebook** to see grade overview
2. Go to individual assignments for detailed grading
3. Leave **Feedback** for students

### Student

#### Join Course
1. Login with provided account
2. Go to **Dashboard** to see enrolled courses
3. Or use **Enrollment key** provided by teacher

#### Learning
1. Enter course, view content by week/topic
2. Download materials, watch lecture videos
3. Complete assignments and quizzes by deadline
4. Participate in discussion forums

#### Track Grades
1. Go to **Grades** to see assignment scores
2. View feedback from teachers
3. Monitor learning progress

## ⚙️ Advanced Configuration

### Change Theme

```bash
# Login with admin privileges
# Go to Site administration → Appearance → Themes
# Choose appropriate theme or upload custom theme
```

### Configure File Upload Limits

Edit the `.env` file:
```bash
# Increase file upload limit (default 2GB)
PHP_UPLOAD_MAX_FILESIZE=5G
PHP_POST_MAX_SIZE=5G

# Apply changes
docker-compose restart moodle
```

### Automatic Backup

```bash
# Database backup
docker-compose exec mariadb mysqldump -u root -p absi_moodle_db > backup-$(date +%Y%m%d).sql

# Moodle data backup
tar -czf moodle-data-$(date +%Y%m%d).tar.gz ./data/moodledata/

# Create daily automatic backup script
echo "0 2 * * * /path/to/backup-script.sh" | crontab -
```

## 🔧 Maintenance and Operations

### Check System Status

```bash
# View container status
docker-compose ps

# View resource usage
docker stats

# View error logs
docker-compose logs moodle | grep ERROR
docker-compose logs mariadb | grep ERROR
```

### System Updates

```bash
# Backup before updating
./backup-script.sh

# Update
docker-compose pull
docker-compose down
docker-compose up -d

# Check after update
docker-compose logs -f moodle
```

### Common Troubleshooting

#### Cannot Access Website
```bash
# Check if containers are running
docker-compose ps

# Check if ports are occupied
netstat -tulpn | grep :80
netstat -tulpn | grep :443

# Restart services
docker-compose restart moodle
```

#### File Upload Errors
- Check disk space: `df -h`
- Check PHP limits in `.env` file
- Restart container: `docker-compose restart moodle`

#### Forgot Admin Password
```bash
# Reset admin password via database
docker-compose exec mariadb mysql -u root -p absi_moodle_db
UPDATE mdl_user SET password=MD5('newpassword') WHERE username='admin';
```

#### Database Errors
```bash
# Check database connection
docker-compose exec moodle php -r "
try {
    new PDO('mysql:host=mariadb;dbname=absi_moodle_db', 'absi_moodle_user', 'password_from_env');
    echo 'Database OK';
} catch(Exception \$e) {
    echo 'Error: ' . \$e->getMessage();
}
"
```

## 📞 Support

### Self-Troubleshooting
1. Check error logs: `docker-compose logs moodle`
2. Restart system: `docker-compose restart`
3. Check configuration file `.env`

### Contact Support
- **Email**: support@absi.edu.vn
- **Hotline**: +84-xxx-xxx-xxx (business hours)
- **Website**: [absi.edu.vn](https://absi.edu.vn)

### Reference Documentation
- [Moodle User Guide](https://docs.moodle.org/)
- [Video Tutorials](https://www.youtube.com/c/moodle)
- [Moodle Community](https://moodle.org/community/)

---

## 🔧 Technical Information (For IT Staff)

<details>
<summary>Technical details and advanced configuration</summary>

### System Architecture

- **PHP 8.4** with FPM and OPcache
- **MariaDB 11.7.2** with InnoDB optimized
- **Apache 2.4** with SSL/TLS
- **Debian 12 Slim** container base

### Technical Features

- **Centralized Configuration**: All settings managed through `scripts/lib/config.sh`
- **Dynamic Build Arguments**: Can change PHP version, user/group
- **Health Checks**: Automatic container monitoring
- **ACL Permissions**: Flexible bind volume permission support
- **Modular Libraries**: Specialized libraries for different functions

### Change PHP Version

```dockerfile
# In Dockerfile, edit this line to change PHP version
ARG PHP_VERSION=8.4  # Can change to 8.1, 8.2, 8.3
```

### Custom Build

```bash
# Build with different PHP version
docker build --build-arg PHP_VERSION=8.3 -t moodle:php83 .

# Build with custom user/group
docker build \
  --build-arg APP_USER=moodle \
  --build-arg APP_GROUP=moodle \
  --build-arg APP_UID=1001 \
  -t moodle:custom .
```

### Production Configuration

#### SSL Certificate
```bash
# Replace self-signed certificate
cp your-domain.crt config/ssl/localhost.crt
cp your-domain.key config/ssl/localhost.key
docker-compose restart moodle
```

#### Performance Tuning
```yaml
# In docker-compose.yml, add resource limits
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
```yaml
# Optimize MariaDB for high-traffic
command:
  - '--innodb-buffer-pool-size=2G'
  - '--innodb-log-file-size=512M'
  - '--innodb-flush-log-at-trx-commit=2'
```

### Project Structure
```
absi-tech-moodle/
├── docker-compose.yml     # Service orchestration
├── Dockerfile            # Container build configuration
├── env.example          # Environment template
├── config/              # Configuration files
├── scripts/             # Setup and management scripts
├── data/               # Persistent data volumes
└── README.md           # This file
```

### Debug Mode
```bash
# Enable debug mode for detailed logs
docker-compose exec moodle bash -c "export DEBUG=true; /scripts/setup/moodle.sh"
```

</details>

---

**Absi Technology** - Educational Technology Solutions  
🌐 Website: [absi.edu.vn](https://absi.edu.vn)  
📧 Email: info@absi.edu.vn  
📱 Phone: +84-xxx-xxx-xxx

*"Empowering Education Through Technology"* 