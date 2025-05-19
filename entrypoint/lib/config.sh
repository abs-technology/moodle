#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

# Generate Moodle config.php from template
generate_moodle_config() {
    local template="/var/www/html/config.php.template"
    local config="/var/www/html/config.php"
    
    # Skip if config exists and we're not reconfiguring
    if [ -f "$config" ] && [ -z "$MOODLE_RECONFIGURE" ]; then
        log_info "Moodle config.php already exists, skipping configuration"
        return 0
    fi
    
    log_info "Generating Moodle config.php from template"
    
    # Check if template exists
    if [ ! -f "$template" ]; then
        log_error "Config template not found at $template"
        return 1
    fi
    
    # Create a copy of the template
    cp "$template" "$config"
    
    # Validate database type, default to mariadb if invalid
    if [ "$MOODLE_DATABASE_TYPE" != "mysqli" ] && [ "$MOODLE_DATABASE_TYPE" != "mariadb" ]; then
        log_warn "Invalid database type: $MOODLE_DATABASE_TYPE. Using mariadb as default."
        MOODLE_DATABASE_TYPE="mariadb"
    fi
    
    # Replace placeholders with actual values
    sed -i "s/{{MOODLE_DATABASE_TYPE}}/$MOODLE_DATABASE_TYPE/g" "$config"
    sed -i "s/{{MOODLE_DATABASE_HOST}}/$MOODLE_DATABASE_HOST/g" "$config"
    sed -i "s/{{MOODLE_DATABASE_NAME}}/$MOODLE_DATABASE_NAME/g" "$config"
    sed -i "s/{{MOODLE_DATABASE_USER}}/$MOODLE_DATABASE_USER/g" "$config"
    sed -i "s/{{MOODLE_DATABASE_PASSWORD}}/$MOODLE_DATABASE_PASSWORD/g" "$config"
    sed -i "s/{{MOODLE_DATABASE_PREFIX}}/$MOODLE_DATABASE_PREFIX/g" "$config"
    sed -i "s/{{MOODLE_DATABASE_PORT}}/$MOODLE_DATABASE_PORT/g" "$config"
    sed -i "s|{{MOODLE_WWWROOT}}|$MOODLE_WWWROOT|g" "$config"
    sed -i "s|{{MOODLE_DATAROOT}}|$MOODLE_DATAROOT|g" "$config"
    
    # Handle boolean values
    if [ "$MOODLE_REVERSEPROXY" = "true" ]; then
        sed -i "s/{{MOODLE_REVERSEPROXY}}/true/g" "$config"
    else
        sed -i "s/{{MOODLE_REVERSEPROXY}}/false/g" "$config"
    fi
    
    if [ "$MOODLE_SSLPROXY" = "true" ]; then
        sed -i "s/{{MOODLE_SSLPROXY}}/true/g" "$config"
    else
        sed -i "s/{{MOODLE_SSLPROXY}}/false/g" "$config"
    fi
    
    # Set proper permissions
    chown moodleuser:moodleuser "$config"
    chmod 644 "$config"
    
    log_info "Moodle config.php generated successfully"
}

# Configure PHP for Moodle
configure_php() {
    log_info "Configuring PHP for Moodle"
    
    # Create PHP config file if it doesn't exist
    local php_config="/usr/local/etc/php/conf.d/moodle-custom.ini"
    
    cat > "$php_config" << EOF
; PHP Configuration for Moodle
memory_limit = ${PHP_MEMORY_LIMIT}
max_execution_time = ${PHP_MAX_EXECUTION_TIME}
upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}
post_max_size = ${PHP_POST_MAX_SIZE}
max_input_vars = 5000
date.timezone = Asia/Ho_Chi_Minh
EOF
    
    log_info "PHP configuration created at $php_config"
}

# Process initialization files
process_init_files() {
    log_info "Processing initialization files"
    
    # Check if initialization directory exists
    if [ ! -d "/docker-entrypoint-initdb.d" ]; then
        log_info "No initialization directory found, skipping"
        return 0
    fi
    
    local f
    for f in /docker-entrypoint-initdb.d/*; do
        if [ ! -f "$f" ]; then
            continue
        fi
        
        case "$f" in
            *.sh)
                if [ -x "$f" ]; then
                    log_info "Running $f"
                    "$f"
                else
                    log_info "Sourcing $f"
                    . "$f"
                fi
                ;;
            *.php)
                log_info "Running $f"
                php "$f"
                ;;
            *.sql)
                if [ -n "$MOODLE_DATABASE_PASSWORD" ]; then
                    log_info "Importing $f"
                    # Sử dụng MySQL hoặc MariaDB tùy theo cấu hình
                    if [ "$MOODLE_DATABASE_TYPE" = "mysqli" ]; then
                        mysql -h "$MOODLE_DATABASE_HOST" -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME" < "$f"
                    else
                        mariadb -h "$MOODLE_DATABASE_HOST" -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME" < "$f" || mysql -h "$MOODLE_DATABASE_HOST" -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME" < "$f"
                    fi
                else
                    log_warn "Skipping SQL import: MOODLE_DATABASE_PASSWORD not set"
                fi
                ;;
            *.sql.gz)
                if [ -n "$MOODLE_DATABASE_PASSWORD" ]; then
                    log_info "Importing $f"
                    if [ "$MOODLE_DATABASE_TYPE" = "mysqli" ]; then
                        gunzip -c "$f" | mysql -h "$MOODLE_DATABASE_HOST" -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME"
                    else
                        gunzip -c "$f" | mariadb -h "$MOODLE_DATABASE_HOST" -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME" || gunzip -c "$f" | mysql -h "$MOODLE_DATABASE_HOST" -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME"
                    fi
                else
                    log_warn "Skipping SQL import: MOODLE_DATABASE_PASSWORD not set"
                fi
                ;;
            *.sql.xz)
                if [ -n "$MOODLE_DATABASE_PASSWORD" ]; then
                    log_info "Importing $f"
                    if [ "$MOODLE_DATABASE_TYPE" = "mysqli" ]; then
                        xzcat "$f" | mysql -h "$MOODLE_DATABASE_HOST" -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME"
                    else
                        xzcat "$f" | mariadb -h "$MOODLE_DATABASE_HOST" -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME" || xzcat "$f" | mysql -h "$MOODLE_DATABASE_HOST" -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME"
                    fi
                else
                    log_warn "Skipping SQL import: MOODLE_DATABASE_PASSWORD not set"
                fi
                ;;
            *.sql.zst)
                if [ -n "$MOODLE_DATABASE_PASSWORD" ]; then
                    log_info "Importing $f"
                    if [ "$MOODLE_DATABASE_TYPE" = "mysqli" ]; then
                        zstd -dc "$f" | mysql -h "$MOODLE_DATABASE_HOST" -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME"
                    else
                        zstd -dc "$f" | mariadb -h "$MOODLE_DATABASE_HOST" -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME" || zstd -dc "$f" | mysql -h "$MOODLE_DATABASE_HOST" -u "$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" "$MOODLE_DATABASE_NAME"
                    fi
                else
                    log_warn "Skipping SQL import: MOODLE_DATABASE_PASSWORD not set"
                fi
                ;;
            *.ini)
                log_info "Copying $f to PHP configuration directory"
                cp "$f" /usr/local/etc/php/conf.d/
                ;;
            *)
                log_warn "Ignoring $f"
                ;;
        esac
    done
    
    log_info "Initialization files processed"
} 