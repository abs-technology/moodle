#!/bin/bash
#############
# ABS Technology Joint Stock Company. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#############

# Print license information
print_license_info() {
    echo -e "\033[1;36m"
    echo "============================================================"
    echo "                LICENSE INFORMATION                         "
    echo "============================================================"
    echo -e "\033[0m"
    
    echo -e "\033[1;33mMoodle ABSI Container Image\033[0m"
    echo "Copyright (c) 2025 ABS Technology Joint Stock Company"
    echo "All rights reserved."
    echo ""
    
    echo -e "\033[1;32mLICENSE NOTICE:\033[0m"
    echo "This container image contains software with different licenses:"
    echo ""
    
    echo -e "\033[1;34m1. Moodle LMS\033[0m"
    echo "   License: GPL-3.0"
    echo "   Website: https://moodle.org/"
    echo "   Source: https://github.com/moodle/moodle"
    echo ""
    
    echo -e "\033[1;34m2. Docker Container Structure\033[0m"
    echo "   License: Apache-2.0"
    echo "   Copyright (c) 2025 ABS Technology Joint Stock Company"
    echo ""
    
    echo -e "\033[1;34m3. ABSI Customizations\033[0m"
    echo "   License: Apache-2.0"
    echo "   Copyright (c) 2025 ABS Technology Joint Stock Company"
    echo ""
    
    echo "For full license texts, please refer to the respective project websites"
    echo "or source repositories."
    echo ""
    
    if [ -f "/opt/absi/LICENSE-NOTICE.txt" ]; then
        echo -e "\033[1;35mDetailed License Notice:\033[0m"
        cat /opt/absi/LICENSE-NOTICE.txt
    fi
    
    echo -e "\033[1;36m"
    echo "============================================================"
    echo -e "\033[0m"
} 