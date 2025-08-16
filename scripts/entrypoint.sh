#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# Tải các thư viện Absi
. /scripts/lib/logging.sh
. /scripts/lib/config.sh
. /scripts/lib/filesystem.sh
. /scripts/lib/service.sh
. /scripts/lib/validations.sh

# Load centralized configuration
load_config

echo -e "\033[1;32mWelcome to Absi Technology Moodle LMS\033[0m" 
echo -e "     ___    __         \033[31m_\033[0m "
echo -e "    /   |  / /_  _____\033[31m(_)\033[0m"
echo -e "   / /| | / __ \/ ___\033[31m/ /\033[0m "
echo -e "  / ___ |/ /_/ (__  )\033[31m /\033[0m  "
echo -e " /_/  |_/_.___/____\033[31m/_/\033[0m   "
                        
echo ""
echo " ══════════════════════════════════════════════"
echo "  🎓 ABSI TECHNOLOGY MOODLE LMS 🎓              "
echo "     Version: 5.0.1+                           "
echo "     PHP Version: 8.4                          "
echo "     Apache Version: 2.4                       "
echo " ══════════════════════════════════════════════"
echo "  📞 Support & Resources                        "
echo "     Website: https://abs.education/            "
echo "     Support: billnguyen@tiki.edu.vn            "
echo "     Professional Services: https://abs.education/mod/page/view.php?id=410 "
echo " ══════════════════════════════════════════════"

echo ""
echo " 🚀 Starting Moodle Docker Container..."
echo " 📅 $(date '+%Y-%m-%d %H:%M:%S')"
echo " 🌐 Container ID: $(hostname)"
echo ""

# Configuration is loaded from config.sh library

debug "Starting entrypoint.sh"
debug "Current directory: $(pwd)"
debug "Current user: $(whoami)"
debug "Environment variables:"

# Fix permissions cho bind volumes (an toàn với ACL)
info "Checking and fixing permissions for bind volumes..."

# Initialize và fix permissions cho Moodle directory
if [ -d "$MOODLE_DIR" ]; then
    # Nếu thư mục trống (bind mount lần đầu), copy mã nguồn từ image
    if [ -z "$(ls -A $MOODLE_DIR)" ]; then
        info "Initializing Moodle source code to bind volume..."
        # Copy từ backup location (được tạo trong Dockerfile)
        if [ -d "$MOODLE_SOURCE_DIR" ]; then
            cp -r $MOODLE_SOURCE_DIR/* $MOODLE_DIR/
            debug "Moodle source code copied to bind volume"
        fi
    fi
    
    # Sử dụng ACL để set permissions an toàn hơn thay vì chown trực tiếp
    if command -v setfacl >/dev/null 2>&1; then
        # Sử dụng ACL để cho phép user access mà không thay đổi ownership gốc
        setfacl -R -m u:$APP_USER:rwx $MOODLE_DIR 2>/dev/null || true
        setfacl -R -m d:u:$APP_USER:rwx $MOODLE_DIR 2>/dev/null || true
        debug "ACL permissions set for $MOODLE_DIR"
    else
        # Fallback: chỉ thêm group write permission
        chgrp -R $APP_USER $MOODLE_DIR 2>/dev/null || true
        chmod -R g+w $MOODLE_DIR 2>/dev/null || true
        debug "Group permissions set for $MOODLE_DIR"
    fi
fi

# Cron will be handled by moodle-run.sh with continuous monitoring
info "Moodle cron will be started and monitored by moodle-run.sh"

# Fix permissions cho moodledata
if [ -d "$MOODLE_DATA_DIR" ]; then
    # Tạo thư mục con cần thiết
    mkdir -p "$MOODLE_DATA_DIR/sessions" "$MOODLE_DATA_DIR/temp" "$MOODLE_DATA_DIR/cache"
    
    # Sử dụng ACL cho moodledata
    if command -v setfacl >/dev/null 2>&1; then
        setfacl -R -m u:$APP_USER:rwx "$MOODLE_DATA_DIR" 2>/dev/null || true
        setfacl -R -m d:u:$APP_USER:rwx "$MOODLE_DATA_DIR" 2>/dev/null || true
        debug "ACL permissions set for $MOODLE_DATA_DIR"
    else
        # Fallback: group permissions
        chgrp -R $APP_USER "$MOODLE_DATA_DIR" 2>/dev/null || true  
        chmod -R g+w "$MOODLE_DATA_DIR" 2>/dev/null || true
        debug "Group permissions set for $MOODLE_DATA_DIR"
    fi
fi

info "** Starting Absi Moodle setup **"

# 1. Setup Web Server (Apache)
info "Setting up Apache..."
debug "Starting Apache setup..."
/scripts/setup/apache.sh
debug "Apache setup completed with exit code: $?"

# 2. Setup PHP
info "Setting up PHP..."
debug "Starting PHP setup..."
/scripts/setup/php.sh
debug "PHP setup completed with exit code: $?"

# 3. Setup SSL Certificates
info "Setting up SSL certificates..."
debug "Starting SSL setup..."
/scripts/setup/ssl.sh
debug "SSL setup completed with exit code: $?"

# 4. Setup Database Client
info "Setting up Database Client..."
debug "Starting Database Client setup..."
/scripts/setup/mariadb.sh
debug "Database Client setup completed with exit code: $?"

# 5. Setup Moodle Application
info "Setting up Moodle application..."
debug "Starting Moodle application setup..."
/scripts/setup/moodle.sh
debug "Moodle application setup completed with exit code: $?"

# 6. Setup Load Balancer Configuration
info "Setting up load balancer configuration..."
debug "Starting load balancer setup..."
/scripts/setup/load-balancer.sh
debug "Load balancer setup completed with exit code: $?"

# 7. Execute custom init scripts
if [[ ! -f "$MOODLE_DATA_DIR/.absi_scripts_initialized" && -d "/docker-entrypoint-init.d" ]]; then
    info "Executing custom user scripts..."
    debug "Checking for init scripts in /docker-entrypoint-init.d"
    read -r -a init_scripts <<< "$(find "/docker-entrypoint-init.d" -type f -print0 | sort -z | xargs -0)"
    if [[ "${#init_scripts[@]}" -gt 0 ]]; then
        debug "Found ${#init_scripts[@]} init scripts"
        mkdir -p "$MOODLE_DATA_DIR" # Đảm bảo thư mục tồn tại để tạo .absi_scripts_initialized
        for init_script in "${init_scripts[@]}"; do
            debug "Executing init script: $init_script"
            script_extension="${init_script##*.}"
            case "$script_extension" in
                "sh")
                    /docker-entrypoint-init.d/shell.sh "$init_script"
                    ;;
                "php")
                    /docker-entrypoint-init.d/php.sh "$init_script"
                    ;;
                "sql"|"sql.gz")
                    /docker-entrypoint-init.d/sql-mariadb.sh "$init_script"
                    ;;
                *)
                    warn "Skipping unknown init script type: $init_script"
                    ;;
            esac
            debug "Init script $init_script completed with exit code: $?"
        done
    else
        debug "No init scripts found"
    fi
    touch "$MOODLE_DATA_DIR/.absi_scripts_initialized"
fi

info "** Absi Moodle setup finished! **"

echo ""
# Chạy các dịch vụ chính (Apache và PHP-FPM)
info "** Starting Absi Moodle services **"
debug "Starting moodle-run.sh..."
exec /scripts/moodle-run.sh
