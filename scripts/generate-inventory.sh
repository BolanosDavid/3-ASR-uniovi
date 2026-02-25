#!/bin/bash
set -e

PROJECT_ROOT="$(dirname "$0")/.."
INVENTORY_DIR="$PROJECT_ROOT/ansible/inventories/generated"
INVENTORY_FILE="$INVENTORY_DIR/inventory.ini"

cd "$PROJECT_ROOT/terraform"

echo "==> Extracting outputs from Terraform..."

PUBLIC_IP=$(terraform output -raw public_ip)
VM_NAME=$(terraform output -raw vm_name)
ADMIN_USER=$(terraform output -raw admin_username)

if [ -z "$PUBLIC_IP" ]; then
    echo "ERROR: Could not get public IP from Terraform outputs"
    exit 1
fi

mkdir -p "$INVENTORY_DIR"

cat > "$INVENTORY_FILE" <<EOF
[webservers]
$VM_NAME ansible_host=$PUBLIC_IP ansible_user=$ADMIN_USER
EOF

echo ""
echo "✓ Inventory generated at: $INVENTORY_FILE"
echo ""
cat "$INVENTORY_FILE"
