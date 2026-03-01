#!/bin/bash
set -e

cd "$(dirname "$0")/../terraform"

echo "==> Applying Terraform configuration..."
terraform apply -auto-approve

echo ""
echo "✓ Infrastructure deployed successfully"
echo ""
terraform output
