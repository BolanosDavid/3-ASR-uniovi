#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
INVENTORY_FILE="$ANSIBLE_DIR/inventories/generated/inventory.ini"

RAW_PRIVATE_KEY_FILE="${ANSIBLE_PRIVATE_KEY_FILE:-$HOME/.ssh/id_rsa}"

case "$RAW_PRIVATE_KEY_FILE" in
  "~/"*)
    PRIVATE_KEY_FILE="$HOME/${RAW_PRIVATE_KEY_FILE#~/}"
    ;;
  *)
    PRIVATE_KEY_FILE="$RAW_PRIVATE_KEY_FILE"
    ;;
esac

if [ ! -f "$INVENTORY_FILE" ]; then
    echo "ERROR: Inventory not found at $INVENTORY_FILE"
    echo "Run ./scripts/generate-inventory.sh first"
    exit 1
fi

if [ ! -f "$PRIVATE_KEY_FILE" ]; then
    echo "ERROR: Private key not found at $PRIVATE_KEY_FILE"
    exit 1
fi

chmod 600 "$PRIVATE_KEY_FILE" 2>/dev/null || true

export ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg"

cd "$ANSIBLE_DIR"

echo "==> Running Ansible playbook..."
echo "==> Using inventory: $INVENTORY_FILE"
echo "==> Using private key: $PRIVATE_KEY_FILE"

ansible-playbook -i "$INVENTORY_FILE" --private-key "$PRIVATE_KEY_FILE" playbooks/site.yml

echo ""
echo "✓ Configuration applied successfully"