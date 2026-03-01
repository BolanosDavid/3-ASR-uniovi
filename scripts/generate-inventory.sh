#!/bin/bash
set -e

PROJECT_ROOT="$(dirname "$0")/.."
INVENTORY_DIR="$PROJECT_ROOT/ansible/inventories/generated"
INVENTORY_FILE="$INVENTORY_DIR/inventory.ini"

cd "$PROJECT_ROOT/terraform"

echo "==> Extracting outputs from Terraform..."

PUBLIC_IPS_JSON=$(terraform output -json public_ips)
ADMIN_USER=$(terraform output -raw admin_username)

if [ -z "$PUBLIC_IPS_JSON" ] || [ -z "$ADMIN_USER" ]; then
    echo "ERROR: Could not get outputs from Terraform"
    exit 1
fi

mkdir -p "$INVENTORY_DIR"

# Cabecera del grupo
cat > "$INVENTORY_FILE" <<'EOL'
[webservers]
EOL

# Escribir una línea por host a partir del mapa JSON
# Ejemplo: asr-vm01 ansible_host=1.2.3.4 ansible_user=azureuser
echo "$PUBLIC_IPS_JSON" | jq -r --arg user "$ADMIN_USER" 'to_entries[] | "\(.key) ansible_host=\(.value) ansible_user=\($user)"' >> "$INVENTORY_FILE"

echo ""
echo "✓ Inventory generated at: $INVENTORY_FILE"
echo ""
cat "$INVENTORY_FILE"