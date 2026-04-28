#!/bin/bash
# auditd setup script
# Configures kernel audit daemon for Phase 2 Advanced Security

set -euo pipefail

echo "[*] Setting up auditd audit framework..."

# Install audit package
sudo apt-get install -y auditd audispd-plugins

# Create audit rules
sudo tee /etc/audit/rules.d/custom.rules > /dev/null << 'AUDITEOF'
# Monitor system calls
-a exit,always -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a exit,always -F arch=b32 -S adjtimex -S settimeofday -k time-change

# Monitor user/group changes
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity

# Monitor sudoers
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# Monitor audit logs
-w /var/log/audit/ -k auditlog
AUDITEOF

# Enable and start auditd
sudo systemctl enable auditd
sudo systemctl restart auditd

echo "[+] auditd configured successfully"
