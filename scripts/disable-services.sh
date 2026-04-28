#!/bin/bash
# Service cleanup script
# Disables unnecessary system services for Phase 1 Security

set -euo pipefail

echo "[*] Disabling unnecessary services..."

# List of services to disable
SERVICES_TO_DISABLE=(
  "avahi-daemon"
  "cups"
  "isc-dhcp-server"
  "bind9"
)

for service in "${SERVICES_TO_DISABLE[@]}"; do
  if systemctl is-enabled "$service" 2>/dev/null; then
    sudo systemctl disable "$service"
    sudo systemctl stop "$service"
    echo "[+] Disabled $service"
  fi
done

echo "[+] Services cleanup complete"
