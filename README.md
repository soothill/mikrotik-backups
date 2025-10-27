# MikroTik Router Configuration Backup Automation

This project uses Ansible to automatically backup MikroTik router configurations to a separate Git repository with full automation.

## Features

- **Automated configuration backup** from multiple MikroTik routers
- **ed25519 SSH key authentication** (more secure than RSA)
- **Separate backup repository** - backups stored in their own git repo
- **Automatic repository initialization** - no manual git setup required
- **Git-optimized versioning** - files are overwritten, git tracks changes
- **Full automation** - repository creation, commits, and pushes handled automatically
- **Configurable via YAML** - all settings in one config file

## Prerequisites

- Python 3.8 or higher
- Python venv module (usually included with Python)
- Git
- Make (usually pre-installed on macOS/Linux)
- SSH access to MikroTik routers with ed25519 key-based authentication
- A private Git repository for storing backups (GitHub, GitLab, etc.)

### Python Dependencies (installed automatically by setup script)
- Ansible 2.9 or higher
- ansible-pylibssh (preferred SSH library for Ansible)
- paramiko (fallback SSH library)
- cryptography

## Quick Start

1. **Set up Python virtual environment and install dependencies:**
   ```bash
   ./setup-venv.sh
   source venv/bin/activate
   ```

2. **Configure your settings** in [config.yml](config.yml):
   ```yaml
   backup_repo:
     local_path: "../mikrotik-config-backups"
     remote_url: "git@github.com:username/mikrotik-config-backups.git"
     branch: "main"
   ```

3. **Configure your routers:**
   ```bash
   cp sample_inventory.yml inventory.yml
   # Edit inventory.yml and add your routers
   ```

4. **Run your first backup:**
   ```bash
   make backup
   ```

The playbook will automatically:
- Create the backup directory
- Initialize a git repository
- Configure git settings
- Create a README in the backup repo
- Back up all router configs
- Commit and push to your remote repository

## Detailed Setup Instructions

### 1. Set Up Python Virtual Environment (Recommended)

Using a virtual environment isolates the project dependencies and prevents conflicts:

```bash
./setup-venv.sh
```

This script will:
- Create a Python virtual environment in `venv/`
- Install Ansible and required Python packages (paramiko, ansible-pylibssh)
- Install required Ansible collections
- Provide usage instructions

After running the setup script, activate the virtual environment:

```bash
source venv/bin/activate
```

### 2. Alternative: System-Wide Installation

If you prefer not to use a virtual environment:

```bash
pip install -r requirements.txt
ansible-galaxy collection install -r requirements.yml
```

**Note:** This requires SSH libraries (paramiko or ansible-pylibssh) to be installed for Ansible to connect to network devices.

### 3. Generate ed25519 SSH Key

If you don't already have an ed25519 key:

```bash
ssh-keygen -t ed25519 -C "mikrotik-backup"
```

Press Enter to save to the default location (`~/.ssh/id_ed25519`).

### 4. Configure SSH Key Authentication on MikroTik Routers

You have two options for setting up SSH key authentication:

#### Option A: Automated User Creation (Recommended)

Use the included playbook to automatically create a user with SSH key access on all routers:

1. Edit [config.yml](config.yml) and uncomment/configure the `user_management` section:
```yaml
user_management:
  enabled: true
  username: "ansible-backup"
  group: "full"  # or "read" for read-only access
  ssh_public_key: "~/.ssh/id_ed25519.pub"
  password: ""  # Leave empty for key-only auth
```

2. Run the user creation playbook:
```bash
make create-user
```

This will automatically:
- Create the user on all routers (or update if exists)
- Upload and configure the SSH public key
- Set appropriate permissions
- Configure key-based authentication

#### Option B: Manual Setup

On each MikroTik router manually:

1. Upload your public SSH key to the router:
```bash
# From your local machine
scp ~/.ssh/id_ed25519.pub admin@<router-ip>:id_ed25519.pub
```

2. Import the key on the router (via SSH or terminal):
```
/user ssh-keys import user=admin public-key-file=id_ed25519.pub
```

3. Ensure SSH service is enabled:
```
/ip service enable ssh
```

4. (Optional) For better security, enable strong crypto:
```
/ip ssh set strong-crypto=yes
```

### 5. Create Your Backup Repository

Create a new **private** repository on GitHub, GitLab, or your Git hosting service:
- Name: `mikrotik-config-backups` (or your preferred name)
- Visibility: **Private** (router configs contain sensitive information!)
- Don't initialize with README (the playbook will create one)

Get the SSH clone URL (e.g., `git@github.com:username/mikrotik-config-backups.git`)

### 6. Configure Settings

Edit [config.yml](config.yml):

```yaml
backup_repo:
  # Where backups are stored locally (can be outside this repo)
  local_path: "../mikrotik-config-backups"

  # Your backup repository URL (MUST be configured!)
  remote_url: "git@github.com:username/mikrotik-config-backups.git"

  # Branch name
  branch: "main"

  # Git commit author info
  git_user:
    name: "MikroTik Backup Bot"
    email: "backup@example.com"

ssh:
  # Path to your ed25519 private key
  private_key: "~/.ssh/id_ed25519"

  # SSH port (default 22)
  port: 22
```

### 7. Configure Your Router Inventory

Create your inventory file from the sample:

```bash
cp sample_inventory.yml inventory.yml
```

Then edit [inventory.yml](inventory.yml) and add your routers:

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
        office-router:
          ansible_host: router.office.example.com
          backup_filename: office-main
      vars:
        ansible_user: admin
```

### 8. (Optional) Enable Auto-Push on Commit

To automatically push changes to git whenever a commit happens in **this** repository:

```bash
make install-hooks
```

This is for the automation repo itself, not the backup repo (which auto-pushes by default).

## Usage

### View Available Commands

```bash
make help
```

### Validate Your Configuration

Before running backups, validate your config file:

```bash
make config-check
```

### Run Backups

```bash
make backup
```

This will:
1. Load configuration from [config.yml](config.yml)
2. Connect to each router via SSH (using ed25519 key)
3. Export router configurations
4. Save to the backup repository directory
5. Initialize git repository (if first run)
6. Configure git settings
7. Commit changes
8. Push to remote repository

### Test Router Connectivity

Before running backups, test SSH connections:

```bash
make test-connection
```

### Create/Update User on Routers

To create or update a user with SSH key access on all routers:

1. Configure the `user_management` section in [config.yml](config.yml)
2. Run:
```bash
make create-user
```

This is useful for:
- Initial setup of SSH key authentication
- Creating dedicated backup users
- Rotating SSH keys
- Adding new users to multiple routers at once

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
| `make config-check` | Validate configuration file |
| `make backup` | Run backup for all routers |
| `make test-connection` | Test SSH connectivity to routers |
| `make create-user` | Create/update user with SSH key on all routers |
| `make install-hooks` | Enable auto-push on git commits (this repo) |
| `make clean` | Remove temporary files and cache |

## Project Structure

```
.
├── Makefile               # Make commands for automation
├── config.yml             # Main configuration file
├── backup-routers.yml     # Main Ansible playbook
├── create-user.yml        # User management playbook
├── sample_inventory.yml   # Sample router inventory (copy to inventory.yml)
├── inventory.yml          # Your router inventory (gitignored, create from sample)
├── requirements.txt       # Python dependencies
├── requirements.yml       # Ansible collection dependencies
├── setup-venv.sh          # Virtual environment setup script
├── .gitignore             # Git ignore rules
├── .git-hooks/           # Git hooks for automation
│   └── post-commit       # Auto-push hook
└── README.md             # This file

../mikrotik-config-backups/  # Backup repository (created automatically)
├── .git/                    # Git repository
├── README.md               # Auto-generated documentation
├── .gitignore             # Ignores Ansible temp files
├── router1-core.rsc       # Router backup files
├── router2-edge.rsc
└── office-main.rsc
```

## How It Works

1. **Load Configuration**: Reads settings from [config.yml](config.yml)
2. **Validate**: Ensures backup repository URL is configured
3. **Connect**: SSH to each router using ed25519 key authentication
4. **Export**: Runs `/export compact` command to get current configuration
5. **Save**: Overwrites backup files (git tracks changes via commits)
6. **Repository Setup**: Initializes git repo, configures remote, user settings
7. **Commit**: Creates a commit with timestamp
8. **Push**: Automatically pushes to remote repository

## Backup File Format

Each backup file is saved as `<backup_filename>.rsc` and contains:
- Router identification metadata (hostname, IP, timestamp in header comments)
- Complete RouterOS configuration in compact format
- **Files are overwritten** on each backup to leverage git's versioning capabilities

Example:
```
# Router: router1
# Host: 192.168.1.1
# Last backup: 2025-10-27T10:30:00+00:00

/interface bridge
add name=bridge1
...
```

## Git Version Control Benefits

Since files are overwritten (not timestamped), you get:
- Clean `git diff` showing exactly what changed in configurations
- `git log` shows complete history of all changes
- `git blame` to see when each line was last modified
- Easy rollback to any previous configuration version
- Efficient storage (git tracks deltas, not full copies)

To view changes:
```bash
cd ../mikrotik-config-backups
git log                          # View commit history
git diff HEAD~1 router1-core.rsc # See what changed in last backup
git show <commit>:router1-core.rsc # View config at specific point in time
```

## Troubleshooting

### Configuration Errors

```bash
make config-check
```

### SSH Connection Issues

Test SSH connectivity manually:
```bash
ssh -i ~/.ssh/id_ed25519 admin@<router-ip>
```

If connection fails:
- Verify the ed25519 key is uploaded to the router
- Check SSH service is enabled on the router
- Verify firewall rules allow SSH connections
- Ensure the correct username is configured

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

If the automatic push fails:
1. Verify your SSH key has access to the remote repository
2. Check your SSH agent has the key loaded:
   ```bash
   ssh-add ~/.ssh/id_ed25519
   ```
3. Test git access:
   ```bash
   ssh -T git@github.com
   ```
4. Manually check the backup repository:
   ```bash
   cd ../mikrotik-config-backups
   git status
   git remote -v
   ```

### Repository Already Exists

If the backup repository already exists locally but needs to be reinitialized:
```bash
# Backup any important data first!
rm -rf ../mikrotik-config-backups
make backup  # Will reinitialize automatically
```

## Security Notes

- **Use ed25519 keys** instead of RSA (smaller, faster, more secure)
- **Never commit SSH private keys** to any repository
- **Use a private Git repository** for storing router configurations
- **Restrict access** to the backup directory and repository
- **Rotate SSH keys regularly** and update router access credentials
- **Consider encrypting** sensitive data in configurations using ansible-vault
- **Review backup files** before pushing to ensure no secrets are exposed
- **Use SSH key passphrases** for additional security
- **Restrict SSH access** on routers to specific IP addresses if possible

## Why ed25519 Instead of RSA?

ed25519 keys offer several advantages:
- **Smaller key size**: 256 bits vs 2048+ bits for RSA
- **Faster**: Quicker key generation and authentication
- **More secure**: Resistant to timing attacks and uses modern cryptography
- **Simpler**: No key size decisions needed
- **Widely supported**: MikroTik RouterOS 6.43+ supports ed25519

## Restore a Configuration

To restore a backed-up configuration to a router:

1. Download the `.rsc` file from your backup repository
2. Upload to the router:
   ```bash
   scp router1-core.rsc admin@192.168.1.1:/
   ```
3. Import on the router:
   ```
   /import file-name=router1-core.rsc
   ```

**Warning**: Importing will overwrite the current configuration. Always backup the current config first!

## License

MIT
