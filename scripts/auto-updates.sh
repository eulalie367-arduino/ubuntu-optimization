#!/bin/bash
# Automatic security updates setup
# Enables unattended-upgrades for Phase 2 Security

set -euo pipefail

echo "[*] Setting up automatic security updates..."

# Install unattended-upgrades
sudo apt-get install -y unattended-upgrades apt-listchanges

# Configure auto-updates
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null << 'UPDATESEOF'
Unattended-Upgrade::Allowed-Origins {
  "${distro_id}:${distro_codename}-security";
};

Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "on-change";
Unattended-Upgrade::AutoRebootWithUsers "false";
Unattended-Upgrade::AutoReboot "false";
UPDATESEOF

# Enable automatic updates
sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null << 'SCHEDULEEOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
SCHEDULEEOF

echo "[+] Automatic updates configured"
