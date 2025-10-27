# MikroTik Router Configuration Backup Automation

This project uses Ansible to automatically backup MikroTik router configurations and commit them to a Git repository.

## Features

- Automated configuration backup from multiple MikroTik routers
- SSH key-based authentication
- Local storage of configuration files
- Automatic Git commit and push to private repository
- Timestamped backups with metadata

## Prerequisites

- Python 3.8 or higher
- Ansible 2.9 or higher
- Git
- Make (usually pre-installed on macOS/Linux)
- SSH access to MikroTik routers with key-based authentication
- A private Git repository for storing backups

## Setup Instructions

### 1. Install Ansible

```bash
pip install ansible
```

### 2. Install Required Ansible Collections

```bash
make install
```

Or using Ansible directly:
```bash
ansible-galaxy collection install -r requirements.yml
```

### 3. Enable Auto-Push on Commit (Optional but Recommended)

To automatically push changes to git whenever a commit happens:

```bash
make install-hooks
```

This installs a git post-commit hook that automatically pushes to the remote repository after each commit. This is especially useful for automated backups - changes will be pushed immediately after being committed.

### 4. Configure SSH Key Authentication on MikroTik Routers

On each MikroTik router, you need to:

1. Upload your public SSH key to the router:
```bash
# From your local machine
scp ~/.ssh/id_rsa.pub admin@<router-ip>:id_rsa.pub
```

2. Import the key on the router:
```
/user ssh-keys import user=admin public-key-file=id_rsa.pub
```

3. Ensure SSH service is enabled:
```
/ip service enable ssh
```

### 5. Configure Your Router Inventory

Edit [inventory.yml](inventory.yml) and add your routers:

```yaml
all:
  children:
    mikrotik_routers:
      hosts:
        router1:
          ansible_host: 192.168.1.1
          backup_filename: router1-core
        router2:
          ansible_host: 192.168.2.1
          backup_filename: router2-edge
      vars:
        ansible_user: admin
        ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

### 6. Initialize Git Repository for Backups

```bash
make init-backup-repo
cd backups
git remote add origin <your-private-repo-url>
git add .gitkeep
git commit -m "Initial commit"
git push -u origin main
```

## Usage

### Quick Start

View all available commands:
```bash
make help
```

### Run the Backup Playbook

```bash
make backup
```

Or using Ansible directly:
```bash
ansible-playbook -i inventory.yml backup-routers.yml
```

### Test Router Connectivity

Before running backups, test SSH connections:
```bash
make test-connection
```

### Schedule Automated Backups

Add a cron job to run backups automatically:

```bash
# Edit crontab
crontab -e

# Add this line to run backups daily at 2 AM
0 2 * * * cd /path/to/mikrotik-backups && make backup >> /var/log/mikrotik-backup.log 2>&1
```

## Available Make Commands

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make install` | Install required Ansible collections |
| `make install-hooks` | Enable auto-push on git commits |
| `make backup` | Run backup for all routers |
| `make test-connection` | Test SSH connectivity to routers |
| `make init-backup-repo` | Initialize Git repository in backups directory |
| `make push-backups` | Manually push backups to Git |
| `make clean` | Remove temporary files and cache |

## Project Structure

```
.
├── Makefile              # Make commands for automation
├── backup-routers.yml    # Main Ansible playbook
├── inventory.yml         # Router inventory configuration
├── requirements.yml      # Ansible dependencies
├── .git-hooks/          # Git hooks for automation
│   └── post-commit      # Auto-push hook
├── backups/             # Directory where configs are stored
│   └── .gitkeep
└── README.md            # This file
```

## How It Works

1. **Connection**: Ansible connects to each router via SSH using key authentication
2. **Export**: Runs `/export compact` command to get the current configuration
3. **Save**: Saves each configuration to `backups/<router-name>.rsc`
4. **Timestamp**: Adds backup timestamp as a comment in each file
5. **Git Commit**: Commits changes to the local Git repository
6. **Auto-Push**: If hooks are installed, automatically pushes to remote repository

## Backup File Format

Each backup file is saved as `<backup_filename>.rsc` in the backups directory with:
- Full router configuration in RouterOS script format
- Timestamp comment at the top
- Compact format (no extra whitespace)

## Troubleshooting

### SSH Connection Issues

Test SSH connectivity manually:
```bash
ssh -i ~/.ssh/id_rsa admin@<router-ip>
```

### Ansible Connection Errors

Test connectivity first:
```bash
make test-connection
```

Or run with verbose output:
```bash
ansible-playbook -i inventory.yml backup-routers.yml -vvv
```

### Git Push Failures

Ensure your Git credentials are configured:
```bash
cd backups
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

For SSH-based Git authentication, ensure your SSH agent has your key loaded:
```bash
ssh-add ~/.ssh/id_rsa
```

## Security Notes

- Never commit your SSH private keys to the repository
- Use a private Git repository for storing router configurations
- Restrict access to the backup directory and files
- Consider encrypting sensitive data in configurations using ansible-vault
- Regularly rotate SSH keys and update router access credentials

## License

MIT
