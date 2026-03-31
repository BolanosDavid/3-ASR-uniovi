#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$PROJECT_ROOT/terraform"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
INVENTORY_FILE="$ANSIBLE_DIR/inventories/generated/inventory.ini"

# Si vale 1, elimina el inventario generado al terminar
CLEAN_INVENTORY="${CLEAN_INVENTORY:-1}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Missing required command: $1"
    exit 1
  }
}

echo "==> Validating dependencies..."
require_cmd terraform

if [ ! -d "$TF_DIR" ]; then
  echo "ERROR: Terraform directory not found at $TF_DIR"
  exit 1
fi

echo "==> Terraform destroy..."
terraform -chdir="$TF_DIR" destroy -auto-approve

if [ "$CLEAN_INVENTORY" = "1" ] && [ -f "$INVENTORY_FILE" ]; then
  rm -f "$INVENTORY_FILE"
  echo "✓ Removed generated inventory: $INVENTORY_FILE"
fi

echo
echo "✓ Infrastructure destroyed successfully"