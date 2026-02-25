#!/bin/bash
set -e

cd "$(dirname "$0")/../terraform"

PUBLIC_IP=$(terraform output -raw public_ip)

if [ -z "$PUBLIC_IP" ]; then
    echo "ERROR: Could not get public IP"
    exit 1
fi

echo "==> Verifying deployment at http://$PUBLIC_IP"
echo ""

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP" || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Web server is responding (HTTP $HTTP_CODE)"
    echo ""
    echo "Page title:"
    curl -s "http://$PUBLIC_IP" | grep -o '<title>[^<]*</title>' | sed 's/<\/*title>//g'
    echo ""
    echo "Access the web server at: http://$PUBLIC_IP"
else
    echo "✗ Web server not responding (HTTP $HTTP_CODE)"
    exit 1
fi
