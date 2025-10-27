.PHONY: help install backup test-connection clean init-backup-repo push-backups install-hooks

# Default target - show help
help:
	@echo "MikroTik Router Backup Automation - Available Commands"
	@echo "======================================================"
	@echo ""
	@echo "Setup Commands:"
	@echo "  make install           - Install required Ansible collections"
	@echo "  make install-hooks     - Install git hooks for auto-push on commit"
	@echo "  make init-backup-repo  - Initialize Git repository in backups directory"
	@echo ""
	@echo "Backup Commands:"
	@echo "  make backup            - Run backup playbook for all routers"
	@echo "  make test-connection   - Test SSH connectivity to all routers"
	@echo ""
	@echo "Git Commands:"
	@echo "  make push-backups      - Manually push backups to Git (included in backup)"
	@echo ""
	@echo "Maintenance Commands:"
	@echo "  make clean             - Remove Ansible cache and temporary files"
	@echo "  make help              - Show this help message"

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

# Run the backup playbook
backup:
	@echo "Starting backup of MikroTik routers..."
	ansible-playbook -i inventory.yml backup-routers.yml

# Test SSH connectivity to all routers
test-connection:
	@echo "Testing connectivity to MikroTik routers..."
	ansible -i inventory.yml mikrotik_routers -m community.routeros.command -a "commands='/system identity print'"

# Initialize Git repository in backups directory
init-backup-repo:
	@echo "Initializing Git repository in backups directory..."
	@if [ ! -d backups/.git ]; then \
		cd backups && \
		git init && \
		echo "Git repository initialized. Don't forget to add your remote:"; \
		echo "  cd backups && git remote add origin <your-repo-url>"; \
	else \
		echo "Git repository already exists in backups directory"; \
	fi

# Manually push backups to Git
push-backups:
	@echo "Pushing backups to Git repository..."
	@if [ -d backups/.git ]; then \
		cd backups && \
		git add . && \
		if git diff-index --quiet HEAD --; then \
			echo "No changes to commit"; \
		else \
			git commit -m "Manual backup commit - $$(date '+%Y-%m-%d %H:%M:%S')" && \
			git push; \
		fi; \
	else \
		echo "Error: backups directory is not a Git repository"; \
		echo "Run 'make init-backup-repo' first"; \
		exit 1; \
	fi

# Clean up temporary files
clean:
	@echo "Cleaning up temporary files..."
	@find . -type f -name "*.retry" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".ansible" -exec rm -rf {} + 2>/dev/null || true
	@echo "Cleanup complete"
