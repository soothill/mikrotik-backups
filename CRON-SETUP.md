# Cron Setup Guide

This guide explains how to set up automated backups using cron.

## Overview

The `cron-backup.sh` script is designed to run from crontab. It automatically:
- Navigates to the project directory
- Activates the Python virtual environment
- Runs the backup using `make backup`
- Logs success and errors to syslog

## Prerequisites

1. Virtual environment must be set up first:
   ```bash
   ./setup-venv.sh
   ```

2. Configuration files must be in place:
   - `config.yml` - with your backup repository settings
   - `inventory.yml` - with your router list

3. Test that backups work manually:
   ```bash
   source venv/bin/activate
   make backup
   ```

## Setting Up Cron

### 1. Edit your crontab
```bash
crontab -e
```

### 2. Add a cron entry

**Daily backup at 2 AM:**
```cron
0 2 * * * /Users/darrensoothill/Documents/GitHub/mikrotik-backups/cron-backup.sh
```

**Every 6 hours:**
```cron
0 */6 * * * /Users/darrensoothill/Documents/GitHub/mikrotik-backups/cron-backup.sh
```

**Every 12 hours (at midnight and noon):**
```cron
0 0,12 * * * /Users/darrensoothill/Documents/GitHub/mikrotik-backups/cron-backup.sh
```

**Weekly on Sunday at 3 AM:**
```cron
0 3 * * 0 /Users/darrensoothill/Documents/GitHub/mikrotik-backups/cron-backup.sh
```

## Cron Schedule Format

```
* * * * * command
│ │ │ │ │
│ │ │ │ └─── Day of week (0-7, Sunday = 0 or 7)
│ │ │ └───── Month (1-12)
│ │ └─────── Day of month (1-31)
│ └───────── Hour (0-23)
└─────────── Minute (0-59)
```

## Viewing Logs

All backup activity is logged to syslog with the tag `mikrotik-backup`.

### View logs on macOS
```bash
# View logs from last 24 hours
log show --predicate 'eventMessage contains "mikrotik-backup"' --last 1d

# View only errors
log show --predicate 'eventMessage contains "mikrotik-backup" AND messageType == error' --last 1d

# Follow logs in real-time
log stream --predicate 'eventMessage contains "mikrotik-backup"'
```

### View logs on Linux
```bash
# View logs
grep mikrotik-backup /var/log/syslog

# Follow logs in real-time
tail -f /var/log/syslog | grep mikrotik-backup

# View with journalctl (systemd)
journalctl -t mikrotik-backup
journalctl -t mikrotik-backup -f  # follow
```

## Using Email Alerts

If you want email alerts on failure, modify the cron entry to use `backup-with-alerts` instead:

1. First, configure email settings in `config.yml`
2. Then use this cron entry:

```cron
0 2 * * * cd /Users/darrensoothill/Documents/GitHub/mikrotik-backups && source venv/bin/activate && make backup-with-alerts
```

## Checking Cron Status

### View current crontab
```bash
crontab -l
```

### Check if cron is running (macOS)
```bash
# View system log for cron activity
log show --predicate 'process == "cron"' --last 1h
```

## Troubleshooting

### Cron job not running
1. Check if cron service is running:
   ```bash
   # macOS
   sudo launchctl list | grep cron
   ```

2. Check system logs:
   ```bash
   # macOS
   log show --predicate 'process == "cron"' --last 1d | grep backup
   ```

3. Test the script manually:
   ```bash
   ./cron-backup.sh
   ```

### Permission issues
Make sure the script is executable:
```bash
chmod +x cron-backup.sh
```

### Environment variables
Cron runs with a minimal environment. The script uses absolute paths to avoid issues, but if you encounter problems:

1. Add environment variables to the script
2. Or specify them in crontab:
   ```cron
   SHELL=/bin/bash
   PATH=/usr/local/bin:/usr/bin:/bin
   0 2 * * * /path/to/cron-backup.sh >> /path/to/logs/cron.log 2>&1
   ```

### SSH key issues
If using SSH keys for git or router access:
1. Make sure SSH keys don't require a passphrase, or
2. Use ssh-agent, or
3. Specify the key explicitly in your config

## macOS Specific Notes

On macOS, cron requires Full Disk Access permission:

1. Open **System Settings** > **Privacy & Security** > **Full Disk Access**
2. Add `/usr/sbin/cron` to the list
3. Alternatively, use `launchd` instead of cron (see below)

### Using launchd (macOS alternative to cron)

Create a plist file at `~/Library/LaunchAgents/com.mikrotik.backup.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.mikrotik.backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/darrensoothill/Documents/GitHub/mikrotik-backups/cron-backup.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/darrensoothill/Documents/GitHub/mikrotik-backups/logs/cron.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/darrensoothill/Documents/GitHub/mikrotik-backups/logs/cron-error.log</string>
</dict>
</plist>
```

Then load it:
```bash
launchctl load ~/Library/LaunchAgents/com.mikrotik.backup.plist
```

## Testing

Before relying on cron, test the script:

```bash
# Test the script manually
./cron-backup.sh

# Check exit code
echo $?

# View syslog output (macOS)
log show --predicate 'eventMessage contains "mikrotik-backup"' --last 5m

# View syslog output (Linux)
journalctl -t mikrotik-backup --since "5 minutes ago"
```
