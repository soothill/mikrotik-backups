#!/bin/bash
#
# MikroTik Backup Automation - Cron Script
# This script is designed to run from crontab and logs to syslog
#
# Add to crontab with: crontab -e
# Example (daily at 2 AM):
#   0 2 * * * /Users/darrensoothill/Documents/GitHub/mikrotik-backups/cron-backup.sh
#
# Example (every 6 hours):
#   0 */6 * * * /Users/darrensoothill/Documents/GitHub/mikrotik-backups/cron-backup.sh
#
# View logs with:
#   log show --predicate 'process == "cron-backup"' --last 1d    (macOS)
#   grep cron-backup /var/log/syslog                             (Linux)
#

set -e

# Syslog tag for all messages
SYSLOG_TAG="mikrotik-backup"

# Function to log to syslog
log_info() {
    logger -t "$SYSLOG_TAG" -p user.info "$1"
}

log_error() {
    logger -t "$SYSLOG_TAG" -p user.error "$1"
}

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || {
    log_error "Failed to change to script directory: $SCRIPT_DIR"
    exit 1
}

# Log start
log_info "Starting MikroTik router backup"

# Check if virtual environment exists
if [ ! -d "$SCRIPT_DIR/venv" ]; then
    log_error "Virtual environment not found at $SCRIPT_DIR/venv - Please run setup-venv.sh first"
    exit 1
fi

# Activate virtual environment
source "$SCRIPT_DIR/venv/bin/activate" || {
    log_error "Failed to activate virtual environment"
    exit 1
}

# Verify ansible is available
if ! command -v ansible-playbook &> /dev/null; then
    log_error "ansible-playbook not found in virtual environment"
    exit 1
fi

# Create temporary file for capturing output
TEMP_LOG=$(mktemp)
trap "rm -f $TEMP_LOG" EXIT

# Run the backup using make
if make backup > "$TEMP_LOG" 2>&1; then
    # Success
    log_info "Backup completed successfully"
    rm -f "$TEMP_LOG"
    exit 0
else
    # Failure - log error with some context
    BACKUP_EXIT_CODE=$?

    # Extract last few lines of error for context
    ERROR_CONTEXT=$(tail -10 "$TEMP_LOG" | tr '\n' ' ' | cut -c 1-200)

    log_error "Backup failed with exit code $BACKUP_EXIT_CODE - $ERROR_CONTEXT"
    log_error "Full log available at: $TEMP_LOG (will be deleted)"

    rm -f "$TEMP_LOG"
    exit $BACKUP_EXIT_CODE
fi
