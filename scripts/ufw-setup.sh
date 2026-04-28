#!/bin/bash
# UFW (Uncomplicated Firewall) setup script
# Configures firewall rules for Phase 1 Security hardening

set -euo pipefail

echo "[*] Configuring UFW firewall..."

# Enable UFW
sudo ufw --force enable

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (critical to avoid lockout)
sudo ufw allow 22/tcp

# Allow standard HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Reload firewall
sudo ufw reload

echo "[+] UFW configured successfully"
