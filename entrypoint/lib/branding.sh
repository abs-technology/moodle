#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

# Colors
RESET='\033[0m'
BLACK_TEXT='\033[0;30m'
RED_TEXT='\033[0;31m'
GREEN_TEXT='\033[0;32m'
YELLOW_TEXT='\033[0;33m'
BLUE_TEXT='\033[0;34m'
MAGENTA_TEXT='\033[0;35m' 
CYAN_TEXT='\033[0;36m'
WHITE_TEXT='\033[0;37m'

# Background colors
BLACK_BG='\033[40m'
RED_BG='\033[41m'
GREEN_BG='\033[42m'
YELLOW_BG='\033[43m'
BLUE_BG='\033[44m'
MAGENTA_BG='\033[45m'
CYAN_BG='\033[46m'
WHITE_BG='\033[47m'

# Show logo ABSI
print_logo_absi() {
    echo -e "${GREEN_TEXT} ############################################"
    echo -e "${GREEN_TEXT}     /\   | |       (_)"
    echo -e "${GREEN_TEXT}    /  \  | |__  ___ _ "
    echo -e "${GREEN_TEXT}   / /\ \ | '_ \/ __| |"
    echo -e "${GREEN_TEXT}  / ____ \| |_) \__ \ |"
    echo -e "${GREEN_TEXT} /_/    \_\_.__/|___/_|"
    echo -e "${GREEN_TEXT} ############################################${RESET}"
}

# Show welcome page
print_welcome_page() {
    echo -e "${CYAN_TEXT}==================================================${RESET}"
    echo -e "${MAGENTA_TEXT}${ABSI_WELCOME}${RESET}"
    echo -e "${CYAN_TEXT}==================================================${RESET}"
    echo -e "${CYAN_TEXT}Copyright (c) 2025 ABS Technology Joint Stock Company${RESET}"
    echo -e "${CYAN_TEXT}All rights reserved.${RESET}"
    echo -e "${CYAN_TEXT}Container structure based on Moodle Docker${RESET}"
    echo -e "${YELLOW_TEXT}Type 'docker exec <container> show-license' for full license details${RESET}"
    echo -e "${CYAN_TEXT}https://abs.education/${RESET}"
    echo -e "${CYAN_TEXT}https://github.com/abs-technology${RESET}"
    echo -e "${CYAN_TEXT}https://www.facebook.com/abs.technology${RESET}"
    echo -e "${CYAN_TEXT}https://www.linkedin.com/company/abs-technology${RESET}"
    echo -e "${CYAN_TEXT}https://www.instagram.com/abs.technology${RESET}"
} 

# Show Moodle version
print_moodle_version() {
    echo -e "${BLUE_TEXT}==================================================${RESET}"
    echo -e "${BLUE_TEXT}Moodle Version: ${APP_VERSION}${RESET}"
    echo -e "${BLUE_TEXT}==================================================${RESET}"
} 