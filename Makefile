.PHONY: help install backup test-connection clean install-hooks config-check

# Default target - show help
help:
	@echo "MikroTik Router Backup Automation - Available Commands"
	@echo "======================================================"
	@echo ""
	@echo "Setup Commands:"
	@echo "  make install           - Install required Ansible collections"
	@echo "  make install-hooks     - Install git hooks for auto-push on commit"
	@echo "  make config-check      - Validate configuration file"
	@echo ""
	@echo "Backup Commands:"
	@echo "  make backup            - Run backup playbook for all routers"
	@echo "  make test-connection   - Test SSH connectivity to all routers"
	@echo ""
	@echo "Maintenance Commands:"
	@echo "  make clean             - Remove Ansible cache and temporary files"
	@echo "  make help              - Show this help message"
	@echo ""
	@echo "Note: The playbook now automatically initializes the backup repository."
	@echo "      Configure your backup repository URL in config.yml before running."

# Install required Ansible collections
install:
	@echo "Installing Ansible collections..."
	ansible-galaxy collection install -r requirements.yml

# Install git hooks for auto-push
install-hooks:
	@echo "Installing git hooks..."
	@if [ -f .git-hooks/post-commit ]; then \
		cp .git-hooks/post-commit .git/hooks/post-commit && \
		chmod +x .git/hooks/post-commit && \
		echo "Git post-commit hook installed successfully"; \
		echo "All future commits will automatically push to remote"; \
	else \
		echo "Error: .git-hooks/post-commit not found"; \
		exit 1; \
	fi

# Validate configuration file
config-check:
	@echo "Validating configuration..."
	@if [ ! -f config.yml ]; then \
		echo "Error: config.yml not found"; \
		exit 1; \
	fi
	@if grep -q 'remote_url: ""' config.yml; then \
		echo "Error: Please set backup_repo.remote_url in config.yml"; \
		echo "Example: remote_url: git@github.com:username/mikrotik-config-backups.git"; \
		exit 1; \
	fi
	@echo "Configuration validated successfully"

# Run the backup playbook
backup: config-check
	@echo "Starting backup of MikroTik routers..."
	ansible-playbook -i inventory.yml backup-routers.yml

# Test SSH connectivity to all routers
test-connection:
	@echo "Testing connectivity to MikroTik routers..."
	ansible -i inventory.yml mikrotik_routers -m community.routeros.command -a "commands='/system identity print'"

# Clean up temporary files
clean:
	@echo "Cleaning up temporary files..."
	@find . -type f -name "*.retry" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".ansible" -exec rm -rf {} + 2>/dev/null || true
	@echo "Cleanup complete"
