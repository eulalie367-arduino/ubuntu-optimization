#!/bin/bash
# SSH hardening script
# Applies security best practices to SSH configuration

set -euo pipefail

echo "[*] Hardening SSH configuration..."

# Backup original config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Apply hardening options
sudo tee -a /etc/ssh/sshd_config > /dev/null << 'SSHEOF'

# Security hardening
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
MaxSessions 5
ClientAliveInterval 300
ClientAliveCountMax 2
SSHEOF

# Validate and reload
sudo sshd -t && sudo systemctl restart ssh

echo "[+] SSH hardened successfully"
