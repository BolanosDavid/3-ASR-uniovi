#!/bin/bash
set -e

cd "$(dirname "$0")/../ansible"

if [ ! -f "inventories/generated/inventory.ini" ]; then
    echo "ERROR: Inventory not found. Run ./scripts/generate-inventory.sh first"
    exit 1
fi

echo "==> Running Ansible playbook..."
ansible-playbook playbooks/site.yml

echo ""
echo "✓ Configuration applied successfully"
