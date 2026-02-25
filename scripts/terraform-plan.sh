#!/bin/bash
set -e

cd "$(dirname "$0")/../terraform"

echo "==> Running Terraform plan..."
terraform plan
