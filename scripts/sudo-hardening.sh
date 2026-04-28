#!/bin/bash
# sudo hardening script
# Restricts and monitors sudo access for Phase 2 Security

set -euo pipefail

echo "[*] Hardening sudo configuration..."

# Create sudoers drop-in file
sudo tee /etc/sudoers.d/99-hardening > /dev/null << 'SUDOEOF'
# Logging
Defaults log_file="/var/log/sudo-commands.log"
Defaults log_format="[%{time} %{hostname}] User=%{user} CMD=%{command}"

# Security
Defaults use_pty
Defaults requiretty
Defaults passwd_timeout=1
Defaults timestamp_timeout=5

# Restrictions
Defaults !visiblepw
SUDOEOF

# Verify syntax
sudo visudo -c

echo "[+] sudo hardened successfully"
