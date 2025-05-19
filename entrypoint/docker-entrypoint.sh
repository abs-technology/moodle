#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

set -o errexit
set -o pipefail
# Không sử dụng set -o nounset để tránh lỗi unbound variable
# set -o nounset
# set -o xtrace # Uncomment this line for debugging purposes

# Load all modules
. /opt/absi/entrypoint/lib/branding.sh
. /opt/absi/entrypoint/lib/logging.sh
. /opt/absi/entrypoint/lib/env.sh
. /opt/absi/entrypoint/lib/helpers.sh
. /opt/absi/entrypoint/lib/license.sh
. /opt/absi/entrypoint/lib/setup.sh
. /opt/absi/entrypoint/lib/moodle.sh
. /opt/absi/entrypoint/lib/ssl.sh
. /opt/absi/entrypoint/lib/apache.sh
. /opt/absi/entrypoint/lib/config.sh
. /opt/absi/entrypoint/lib/post_init.sh

# Print welcome message
print_logo_absi
print_welcome_page

# Display Moodle version
print_moodle_version

# Main function
_main() {
    # Check if running as root
    if [ "$(id -u)" = "0" ]; then
        # Handle special cases
        if [ "$1" = 'license' ] || [ "$1" = 'show-license' ]; then
            print_license_info
            exit 0
        fi
        
        # Setup for Apache or PHP-FPM
        if [ "$1" = 'apache2-foreground' ] || [ "$1" = 'php-fpm' ]; then
            log_info "Setting up Moodle environment"
            
            # 1. Basic environment setup
            setup_moodle_environment
            
            # 2. Setup Apache
            setup_apache
            
            # 3. Setup SSL
            setup_ssl
            
            # 4. Configure PHP for Moodle
            configure_php
            
            # 5. Database related operations
            if [ -z "$MOODLE_SKIP_INSTALL" ] && [ -n "$MOODLE_DATABASE_PASSWORD" ]; then
                # Wait for database to be ready
                wait_for_db "$MOODLE_DATABASE_HOST" "$MOODLE_DATABASE_PORT" "$MOODLE_DATABASE_USER" "$MOODLE_DATABASE_PASSWORD"
                
                # Generate Moodle config.php if needed
                if [ -n "$MOODLE_DATABASE_PASSWORD" ]; then
                    generate_moodle_config
                else
                    log_warn "MOODLE_DATABASE_PASSWORD not set, skipping Moodle configuration"
                fi
                
                # Kiểm tra và cài đặt Moodle nếu cần thiết (hỗ trợ tự động cài đặt)
                check_and_install_moodle
                
                # Thực hiện nâng cấp nếu cần thiết
                if [ "$MOODLE_AUTO_INSTALL" != "true" ]; then
                    if ! is_moodle_db_installed; then
                        install_moodle
                    else
                        upgrade_moodle
                    fi
                else
                    # Nếu AUTO_INSTALL đã cài đặt Moodle, vẫn cần thiết lập cron
                    if is_moodle_db_installed; then
                        log_info "Auto-install was successful, setting up cron job"
                        setup_moodle_cron
                    fi
                fi
            fi
            
            # 6. Process any initialization files
            if [ -d "/docker-entrypoint-initdb.d" ]; then
                log_info "Processing initialization files"
                process_init_files
            fi
            
            # 7. Run post-initialization tasks
            post_init_tasks
            
            # 8. Verify installation
            verify_moodle_installation || log_warn "Moodle installation verification failed, but continuing with startup"
            
            # 9. Final check of permissions
            log_info "Final check of Apache permissions"
            ls -la /var/run/apache2 /var/lock/apache2
            
            # 10. Start cron service if needed
            start_cron_service || log_warn "Failed to start cron service, but continuing with startup"
            
            # 11. Switch to dedicated user and execute command
            log_info "Switching to dedicated user 'moodleuser'"
            exec gosu moodleuser "$@"
        fi
    fi

    # If not running as root or not one of the special commands, just execute the command
    exec "$@"
}

# Run main function if not sourced
if ! _is_sourced; then
    _main "$@"
fi 