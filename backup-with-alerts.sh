#!/bin/bash
#
# MikroTik Backup Wrapper with Email Alerts
# This script runs the backup playbook and sends email alerts on failure
#

set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Log file
LOG_FILE="${SCRIPT_DIR}/logs/backup-$(date +%Y%m%d-%H%M%S).log"
LATEST_LOG="${SCRIPT_DIR}/logs/backup-latest.log"

# Create logs directory
mkdir -p "${SCRIPT_DIR}/logs"

# Function to send alert
send_alert() {
    local subject="$1"
    local body="$2"

    # Try to send email using Python script
    if [ -f "${SCRIPT_DIR}/send-alert.py" ]; then
        python3 "${SCRIPT_DIR}/send-alert.py" "$subject" "$body" 2>&1
    fi
}

# Function to extract error details from log
extract_error_details() {
    local log_file="$1"

    # Try to find the most relevant error information
    local error_msg=""

    # Look for ERROR lines
    if grep -q "\[ERROR\]" "$log_file"; then
        error_msg=$(grep -A 5 "\[ERROR\]" "$log_file" | head -20)
    fi

    # Look for fatal errors
    if grep -q "fatal:" "$log_file"; then
        error_msg="${error_msg}\n\n$(grep -B 2 -A 3 "fatal:" "$log_file" | head -20)"
    fi

    # Look for failed tasks
    if grep -q "FAILED!" "$log_file"; then
        error_msg="${error_msg}\n\n$(grep -B 3 "FAILED!" "$log_file" | head -20)"
    fi

    if [ -z "$error_msg" ]; then
        error_msg="Check log file for details: $log_file"
    fi

    echo -e "$error_msg"
}

# Main execution
echo -e "${GREEN}Starting MikroTik Router Backup...${NC}"
echo "Log file: $LOG_FILE"
echo ""

# Run the backup playbook
if ansible-playbook -i inventory.yml backup-routers.yml 2>&1 | tee "$LOG_FILE"; then
    # Success
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Backup completed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"

    # Update latest log symlink
    ln -sf "$(basename "$LOG_FILE")" "$LATEST_LOG"

    # Check if configuration changes were detected
    CHANGES_FILE="${SCRIPT_DIR}/logs/config-changes.txt"
    if [ -f "$CHANGES_FILE" ]; then
        echo ""
        echo -e "${YELLOW}Configuration changes detected!${NC}"
        echo -e "${YELLOW}Sending change notification email...${NC}"

        # Read the changes
        CHANGE_DETAILS=$(cat "$CHANGES_FILE")

        # Prepare email body
        EMAIL_BODY="Router configuration changes have been detected and backed up successfully.

${CHANGE_DETAILS}

Backup Repository: Check your git repository for full diff
Log File: ${LOG_FILE}

To view changes in the backup repository:
    cd $(grep -A 1 'backup_repo:' config.yml | grep 'local_path:' | awk '{print $2}' | tr -d '"')
    git log -1 -p
    git diff HEAD~1

This is an informational alert. The backup completed successfully and changes have been committed to the repository.
"

        # Send change notification email
        send_alert "Configuration Changes Detected" "$EMAIL_BODY"

        # Remove the changes file after processing
        rm -f "$CHANGES_FILE"
    fi

    exit 0
else
    # Failure
    BACKUP_EXIT_CODE=$?

    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Backup FAILED!${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""

    # Update latest log symlink
    ln -sf "$(basename "$LOG_FILE")" "$LATEST_LOG"

    # Extract error details
    ERROR_DETAILS=$(extract_error_details "$LOG_FILE")

    # Prepare email body
    EMAIL_BODY="MikroTik router backup failed!

Exit Code: ${BACKUP_EXIT_CODE}
Log File: ${LOG_FILE}

Error Details:
${ERROR_DETAILS}

To view the full log:
    cat ${LOG_FILE}

To retry manually:
    cd ${SCRIPT_DIR}
    make backup
"

    # Send alert email
    echo -e "${YELLOW}Sending failure alert email...${NC}"
    send_alert "Backup Failed" "$EMAIL_BODY"

    exit $BACKUP_EXIT_CODE
fi
