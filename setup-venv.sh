#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}MikroTik Backup Automation - Virtual Environment Setup${NC}"
echo "=========================================================="
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    echo "Please install Python 3.8 or higher"
    exit 1
fi

# Display Python version
PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✓${NC} Found $PYTHON_VERSION"

# Check for venv module
if ! python3 -c "import venv" &> /dev/null; then
    echo -e "${RED}Error: Python venv module not found${NC}"
    echo "Please install it with: sudo apt-get install python3-venv (Debian/Ubuntu)"
    exit 1
fi

# Remove existing venv if it exists
if [ -d "venv" ]; then
    echo -e "${YELLOW}⚠${NC}  Existing virtual environment found"
    read -p "Do you want to remove it and create a new one? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Removing existing virtual environment...${NC}"
        rm -rf venv
    else
        echo "Keeping existing virtual environment"
        exit 0
    fi
fi

# Create virtual environment
echo ""
echo "Creating virtual environment..."
python3 -m venv venv
echo -e "${GREEN}✓${NC} Virtual environment created"

# Activate virtual environment
echo ""
echo "Activating virtual environment..."
source venv/bin/activate
echo -e "${GREEN}✓${NC} Virtual environment activated"

# Upgrade pip
echo ""
echo "Upgrading pip..."
pip install --upgrade pip > /dev/null
echo -e "${GREEN}✓${NC} pip upgraded"

# Install Ansible
echo ""
echo "Installing Ansible..."
pip install ansible
echo -e "${GREEN}✓${NC} Ansible installed"

# Display Ansible version
ANSIBLE_VERSION=$(ansible --version | head -n 1)
echo -e "${GREEN}✓${NC} $ANSIBLE_VERSION"

# Install Ansible collections
echo ""
echo "Installing Ansible collections..."
ansible-galaxy collection install -r requirements.yml
echo -e "${GREEN}✓${NC} Ansible collections installed"

# Deactivate virtual environment for now
deactivate

echo ""
echo -e "${GREEN}=========================================================="
echo "Setup Complete!"
echo "==========================================================${NC}"
echo ""
echo "To use the virtual environment:"
echo ""
echo -e "  ${YELLOW}source venv/bin/activate${NC}    # Activate the virtual environment"
echo -e "  ${YELLOW}make backup${NC}                 # Run your backups"
echo -e "  ${YELLOW}deactivate${NC}                  # Exit the virtual environment when done"
echo ""
echo "Or use the virtual environment directly without activating:"
echo ""
echo -e "  ${YELLOW}venv/bin/ansible-playbook -i inventory.yml backup-routers.yml${NC}"
echo ""
