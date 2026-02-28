#!/bin/bash
# Verify that all deployed VMs are reachable and serving HTTP content.
#
# Este script lee las IPs públicas de los outputs de Terraform y realiza
# una petición HTTP a cada VM para comprobar que el servidor web está activo.

set -e

# Ruta al proyecto
PROJECT_ROOT="$(dirname "$0")/.."

# Acceder al directorio de Terraform
cd "$PROJECT_ROOT/terraform"

echo "==> Verifying deployment by checking HTTP responses from all VMs..."

# Obtener el mapa de IPs públicas
PUBLIC_IPS_JSON=$(terraform output -json public_ips)

if [ -z "$PUBLIC_IPS_JSON" ]; then
    echo "ERROR: Could not retrieve public IPs from Terraform outputs."
    exit 1
fi

# Iterar sobre cada par nombre/IP y lanzar curl
ALL_OK=1
echo "$PUBLIC_IPS_JSON" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read -r name ip; do
    echo "\nChecking VM $name at $ip..."
    if curl -s -I --connect-timeout 10 "http://$ip" | grep -qi "200 ok"; then
        echo "✓ $name ($ip) responded correctly to HTTP request."
    else
        echo "ERROR: $name ($ip) did not respond as expected."
        ALL_OK=0
    fi
done

if [ "$ALL_OK" -eq 1 ]; then
    echo "\nAll VMs responded successfully. Deployment verified."
else
    echo "\nSome VMs did not respond correctly. Please investigate."
    exit 1
fi