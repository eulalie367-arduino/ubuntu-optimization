#!/bin/bash
# Swap optimization script
# Optimizes memory management for Phase 1 Performance

set -euo pipefail

echo "[*] Optimizing swap configuration..."

# Set swappiness (prefer RAM over swap)
sudo sysctl -w vm.swappiness=10

# Enable zswap if available
if [ -e /sys/module/zswap ]; then
  echo y | sudo tee /sys/module/zswap/parameters/enabled > /dev/null
  echo "[+] zswap enabled"
fi

# Enable TRIM on mount
sudo mount -o remount,discard /

echo "[+] Swap optimization complete"
