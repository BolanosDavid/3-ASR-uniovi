#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$PROJECT_ROOT/terraform"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
INVENTORY_FILE="$ANSIBLE_DIR/inventories/generated/inventory.ini"

ASR_KEY_NAME="${ASR_KEY_NAME:-asr_azure_rsa}"
KEY_PRIVATE="$HOME/.ssh/$ASR_KEY_NAME"
KEY_PUBLIC="$KEY_PRIVATE.pub"
TFVARS_FILE="$TF_DIR/terraform.tfvars"
TFVARS_EXAMPLE="$TF_DIR/terraform.tfvars.example"
SSH_READY_ATTEMPTS="${SSH_READY_ATTEMPTS:-30}"
SSH_READY_SLEEP="${SSH_READY_SLEEP:-5}"

WG_CLIENT_NAME="${WG_CLIENT_NAME:-operator}"
WG_CLIENT_OVERLAY_IP="${WG_CLIENT_OVERLAY_IP:-10.8.0.254}"
WG_CLIENT_DIR="${WG_CLIENT_DIR:-$PROJECT_ROOT/ansible/inventories/generated/wireguard-client}"
WG_CLIENT_PRIVATE_KEY_FILE="$WG_CLIENT_DIR/${WG_CLIENT_NAME}.key"
WG_CLIENT_PUBLIC_KEY_FILE="$WG_CLIENT_DIR/${WG_CLIENT_NAME}.pub"
WG_ANSIBLE_VARS_FILE="$WG_CLIENT_DIR/${WG_CLIENT_NAME}.auto-vars.yml"

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

detect_public_ip() {
  local ip=""
  if command -v curl >/dev/null 2>&1; then
    ip="$(curl -fsS --max-time 5 https://api.ipify.org || true)"
  fi
  printf '%s' "$ip"
}

echo "==> Validating dependencies..."
require_cmd ssh-keygen
require_cmd terraform
require_cmd jq
require_cmd ansible-playbook
require_cmd timeout
require_cmd wg

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

echo "==> Preparing local WireGuard operator client..."
mkdir -p "$WG_CLIENT_DIR"
chmod 700 "$WG_CLIENT_DIR"

if [ ! -f "$WG_CLIENT_PRIVATE_KEY_FILE" ] || [ ! -f "$WG_CLIENT_PUBLIC_KEY_FILE" ]; then
  umask 077
  wg genkey | tee "$WG_CLIENT_PRIVATE_KEY_FILE" | wg pubkey > "$WG_CLIENT_PUBLIC_KEY_FILE"
  echo "✓ Generated WireGuard client keypair:"
  echo "   Private: $WG_CLIENT_PRIVATE_KEY_FILE"
  echo "   Public : $WG_CLIENT_PUBLIC_KEY_FILE"
else
  echo "✓ Reusing existing WireGuard client keypair:"
  echo "   Private: $WG_CLIENT_PRIVATE_KEY_FILE"
  echo "   Public : $WG_CLIENT_PUBLIC_KEY_FILE"
fi

OPERATOR_PUBLIC_IP="$(detect_public_ip || true)"
if [ -n "$OPERATOR_PUBLIC_IP" ]; then
  echo "✓ Detected operator public IP: $OPERATOR_PUBLIC_IP"
else
  echo "WARNING: Could not detect operator public IP automatically."
  echo "         This does not block VPN generation because the server side does not need it."
fi

WG_CLIENT_PUBLIC_KEY="$(tr -d '\n' < "$WG_CLIENT_PUBLIC_KEY_FILE")"
WG_CLIENT_PRIVATE_KEY="$(tr -d '\n' < "$WG_CLIENT_PRIVATE_KEY_FILE")"

cat > "$WG_ANSIBLE_VARS_FILE" <<EOF
wireguard_operator_client_enabled: true
wireguard_operator_client_name: "$WG_CLIENT_NAME"
wireguard_operator_client_overlay_ip: "$WG_CLIENT_OVERLAY_IP"
wireguard_operator_client_public_key: "$WG_CLIENT_PUBLIC_KEY"
wireguard_operator_client_private_key: "$WG_CLIENT_PRIVATE_KEY"
wireguard_operator_client_public_ip: "${OPERATOR_PUBLIC_IP}"
wireguard_operator_client_output_dir: "$WG_CLIENT_DIR"
EOF
chmod 600 "$WG_ANSIBLE_VARS_FILE"

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
export ANSIBLE_EXTRA_VARS_FILE="$WG_ANSIBLE_VARS_FILE"
"$PROJECT_ROOT/scripts/ansible-run.sh"

echo "==> Verifying HTTP deployment..."
"$PROJECT_ROOT/scripts/verify-deployment.sh"

echo
echo "✓ Full deployment completed successfully"
echo "✓ SSH key used: $KEY_PRIVATE"
echo "✓ Inventory: $INVENTORY_FILE"
echo "✓ WireGuard client config: $WG_CLIENT_DIR/${WG_CLIENT_NAME}.conf"
echo
echo "Next step:"
echo "  Import $WG_CLIENT_DIR/${WG_CLIENT_NAME}.conf into your WireGuard client"
echo "  Then access Grafana at: http://10.8.0.1:3000"