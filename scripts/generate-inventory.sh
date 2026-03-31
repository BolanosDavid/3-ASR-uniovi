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

# Base IP for the WireGuard overlay network (10.8.0.0/24).
# Each host gets 10.8.0.<index+1> assigned sequentially in sorted order.
WG_BASE="10.8.0"

{
    echo "[webservers]"
    # Sort hosts by name so WireGuard IP assignment is deterministic regardless
    # of the order Terraform returns them. Each host receives wg_overlay_ip
    # as a host variable so Ansible roles never need to hardcode IP mappings.
    index=1
    while IFS= read -r line; do
        echo "$line wg_overlay_ip=${WG_BASE}.${index}"
        index=$((index + 1))
    done < <(echo "$PUBLIC_IPS_JSON" | jq -r --arg user "$ADMIN_USER" \
      'to_entries | sort_by(.key) | .[] | "\(.key) ansible_host=\(.value) ansible_user=\($user)"')
} > "$INVENTORY_FILE"