#!/bin/bash
# PREEMPT_RT patch application
# Applies real-time kernel patch for Phase 3 Customization

set -euo pipefail

KERNEL_DIR="${1:-.}"
PATCH_URL="https://www.kernel.org/pub/linux/kernel/projects/rt/"

echo "[*] Applying PREEMPT_RT patch..."

cd "$KERNEL_DIR"

# Detect kernel version
KVER=$(make kernelversion)
PATCH_FILE="patch-${KVER}-rt.patch.gz"

echo "[*] Downloading patch for kernel $KVER..."
wget -q "$PATCH_URL/$PATCH_FILE" -O "/tmp/$PATCH_FILE"

# Apply patch
gunzip -c "/tmp/$PATCH_FILE" | patch -p1

echo "[+] PREEMPT_RT patch applied"
