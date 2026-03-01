#!/bin/bash
set -e

cd "$(dirname "$0")/../terraform"

echo "==> Initializing Terraform..."
terraform init

echo ""
echo "✓ Terraform initialized successfully"
