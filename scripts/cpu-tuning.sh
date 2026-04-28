#!/bin/bash
# CPU tuning script
# Optimizes CPU governor and frequency scaling for Phase 2 Performance

set -euo pipefail

echo "[*] Tuning CPU configuration..."

# Install cpufrequtils if needed
if ! command -v cpufreq-info &> /dev/null; then
  sudo apt-get install -y cpufrequtils
fi

# Set CPU governor to performance
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo "performance" | sudo tee "$cpu" > /dev/null
done

# Set CPU frequency scaling
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
  # Set to maximum frequency
  MAX_FREQ=$(cat "$(dirname "$cpu")/cpuinfo_max_freq")
  echo "$MAX_FREQ" | sudo tee "$cpu" > /dev/null
done

echo "[+] CPU tuning complete"
