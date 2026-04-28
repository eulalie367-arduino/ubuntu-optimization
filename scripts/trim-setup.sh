#!/bin/bash
# TRIM automation script
# Sets up periodic TRIM for SSD optimization

set -euo pipefail

echo "[*] Setting up TRIM automation..."

# Enable fstrim.timer for daily TRIM
sudo systemctl enable fstrim.timer
sudo systemctl start fstrim.timer

# Check status
sudo systemctl status fstrim.timer

echo "[+] TRIM automation configured"
