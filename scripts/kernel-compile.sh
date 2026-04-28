#!/bin/bash
# Kernel compilation script
# Handles kernel building and installation for Phase 3 Customization

set -euo pipefail

KERNEL_VERSION="${1:-6.6}"
BUILD_DIR="/tmp/kernel-build-$$"

echo "[*] Building custom kernel v$KERNEL_VERSION..."

# Install build dependencies
sudo apt-get install -y build-essential libncurses-dev bison flex libssl-dev libelf-dev

# Download kernel source
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
wget -q "https://www.kernel.org/releases/kernel-v6.x/linux-$KERNEL_VERSION.tar.xz"
tar -xf "linux-$KERNEL_VERSION.tar.xz"
cd "linux-$KERNEL_VERSION"

# Copy custom config
cp /tmp/kernel.config .config

# Build
make -j$(nproc) > /dev/null 2>&1
make modules -j$(nproc) > /dev/null 2>&1

# Install
sudo make modules_install
sudo make install

echo "[+] Kernel compilation complete"
