#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$PROJECT_ROOT/terraform"
INVENTORY_DIR="$PROJECT_ROOT/ansible/inventories/generated"
INVENTORY_FILE="$INVENTORY_DIR/inventory.ini"

echo "==> Project root: $PROJECT_ROOT"
echo "==> Terraform dir: $TF_DIR"
echo "==> Inventory file: $INVENTORY_FILE"
echo "==> Extracting outputs from Terraform..."

PUBLIC_IPS_JSON="$(terraform -chdir="$TF_DIR" output -json public_ips)"
ADMIN_USER="$(terraform -chdir="$TF_DIR" output -raw admin_username)"

if [ -z "$PUBLIC_IPS_JSON" ] || [ -z "$ADMIN_USER" ]; then
    echo "ERROR: Could not get outputs from Terraform"
    exit 1
fi

mkdir -p "$INVENTORY_DIR"

{
    echo "[webservers]"
    echo "$PUBLIC_IPS_JSON" | jq -r --arg user "$ADMIN_USER" \
      'to_entries[] | "\(.key) ansible_host=\(.value) ansible_user=\($user)"'
} > "$INVENTORY_FILE"

echo ""
echo "✓ Inventory generated at: $INVENTORY_FILE"
echo ""
cat "$INVENTORY_FILE"