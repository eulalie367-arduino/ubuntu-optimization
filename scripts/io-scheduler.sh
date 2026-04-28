#!/bin/bash
# I/O scheduler optimization
# Configures optimal I/O scheduler for Phase 2 Performance

set -euo pipefail

echo "[*] Optimizing I/O scheduler..."

# Detect block devices
for device in /sys/block/*/queue/scheduler; do
  DISK=$(echo "$device" | cut -d'/' -f4)
  
  # Use mq-deadline for high-performance systems
  if grep -q "mq-deadline" "$device" 2>/dev/null; then
    echo "mq-deadline" | sudo tee "$device" > /dev/null
    echo "[+] Set $DISK to mq-deadline"
  fi
done

echo "[+] I/O scheduler optimization complete"
