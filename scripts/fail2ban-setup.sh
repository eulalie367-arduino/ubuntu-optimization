#!/bin/bash
# fail2ban setup script
# Configures intrusion detection system for Phase 1 Security

set -euo pipefail

echo "[*] Setting up fail2ban IDS..."

# Install fail2ban
sudo apt-get install -y fail2ban

# Copy default jail config
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Enable and start service
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

echo "[+] fail2ban configured successfully"
