#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$PROJECT_ROOT/terraform"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
INVENTORY_FILE="$ANSIBLE_DIR/inventories/generated/inventory.ini"

# Configurable por variables de entorno
ASR_KEY_NAME="${ASR_KEY_NAME:-asr_azure_rsa}"
KEY_PRIVATE="$HOME/.ssh/$ASR_KEY_NAME"
KEY_PUBLIC="$KEY_PRIVATE.pub"
TFVARS_FILE="$TF_DIR/terraform.tfvars"
TFVARS_EXAMPLE="$TF_DIR/terraform.tfvars.example"
SSH_READY_ATTEMPTS="${SSH_READY_ATTEMPTS:-30}"
SSH_READY_SLEEP="${SSH_READY_SLEEP:-5}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Missing required command: $1"
    exit 1
  }
}

replace_or_append_tfvar() {
  local key="$1"
  local value="$2"

  if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$TFVARS_FILE"; then
    sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$TFVARS_FILE"
  else
    printf '\n%s = %s\n' "$key" "$value" >> "$TFVARS_FILE"
  fi
}

wait_for_ssh_port() {
  local ip="$1"
  local attempt=1

  while [ "$attempt" -le "$SSH_READY_ATTEMPTS" ]; do
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$ip/22" 2>/dev/null; then
      echo "✓ SSH ready on $ip"
      return 0
    fi

    echo "   [$attempt/$SSH_READY_ATTEMPTS] Waiting for SSH on $ip..."
    sleep "$SSH_READY_SLEEP"
    attempt=$((attempt + 1))
  done

  echo "ERROR: SSH did not become available on $ip"
  return 1
}

echo "==> Validating dependencies..."
require_cmd ssh-keygen
require_cmd terraform
require_cmd jq
require_cmd ansible-playbook
require_cmd timeout

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

echo "==> Preparing dedicated RSA key for the project..."
if [ ! -f "$KEY_PRIVATE" ] || [ ! -f "$KEY_PUBLIC" ]; then
  ssh-keygen -m PEM -t rsa -b 4096 -f "$KEY_PRIVATE" -C "asr-azure-$(whoami)" -N ""
  echo "✓ Created key pair:"
  echo "   Private: $KEY_PRIVATE"
  echo "   Public : $KEY_PUBLIC"
else
  echo "✓ Reusing existing key pair:"
  echo "   Private: $KEY_PRIVATE"
  echo "   Public : $KEY_PUBLIC"
fi

if ! grep -q '^ssh-rsa ' "$KEY_PUBLIC"; then
  echo "ERROR: $KEY_PUBLIC is not an RSA public key (must start with 'ssh-rsa ')."
  exit 1
fi

echo "==> Preparing terraform.tfvars..."
if [ ! -f "$TFVARS_FILE" ]; then
  if [ -f "$TFVARS_EXAMPLE" ]; then
    cp "$TFVARS_EXAMPLE" "$TFVARS_FILE"
    echo "✓ Created $TFVARS_FILE from example"
  else
    echo "ERROR: Missing $TFVARS_FILE and $TFVARS_EXAMPLE"
    exit 1
  fi
fi

replace_or_append_tfvar "ssh_public_key_path" "\"~/.ssh/${ASR_KEY_NAME}.pub\""

echo "==> Terraform init..."
terraform -chdir="$TF_DIR" init

echo "==> Terraform apply..."
terraform -chdir="$TF_DIR" apply -auto-approve

echo "==> Generating Ansible inventory..."
"$PROJECT_ROOT/scripts/generate-inventory.sh"

if [ ! -f "$INVENTORY_FILE" ]; then
  echo "ERROR: Inventory was not generated at $INVENTORY_FILE"
  exit 1
fi

echo "==> Waiting for SSH to become available on all VMs..."
terraform -chdir="$TF_DIR" output -json public_ips \
  | jq -r 'to_entries[] | "\(.key) \(.value)"' \
  | while read -r name ip; do
      echo "-> $name ($ip)"
      wait_for_ssh_port "$ip"
    done

echo "==> Running Ansible..."
export ANSIBLE_PRIVATE_KEY_FILE="$KEY_PRIVATE"
"$PROJECT_ROOT/scripts/ansible-run.sh"

echo "==> Verifying HTTP deployment..."
"$PROJECT_ROOT/scripts/verify-deployment.sh"

echo
echo "✓ Full deployment completed successfully"
echo "✓ SSH key used: $KEY_PRIVATE"
echo "✓ Inventory: $INVENTORY_FILE"