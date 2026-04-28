#!/bin/bash
################################################################################
# Build Ubuntu Autoinstall ISO
# Extracts Ubuntu ISO, injects installer files, repacks with xorriso
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓ $*${NC}"
}

log_error() {
    echo -e "${RED}✗ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $*${NC}"
}

# Parse arguments
if [ $# -lt 1 ]; then
    log_error "Usage: $0 <ubuntu-iso-file>"
    log "Example: $0 ubuntu-22.04.3-live-server-amd64.iso"
    exit 1
fi

UBUNTU_ISO="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"
OUTPUT_ISO="$OUTPUT_DIR/ubuntu-optimized-autoinstall.iso"
WORK_DIR="/tmp/ubuntu-autoinstall-$$"

log "Ubuntu Autoinstall ISO Builder"
log "Input ISO: $UBUNTU_ISO"
log "Output ISO: $OUTPUT_ISO"
log "Working directory: $WORK_DIR"

# Check if input ISO exists
if [ ! -f "$UBUNTU_ISO" ]; then
    log_error "ISO file not found: $UBUNTU_ISO"
    exit 1
fi

# Check if required tools are installed
for tool in xorriso unsquashfs mksquashfs; do
    if ! command -v "$tool" &> /dev/null; then
        log_error "Required tool not found: $tool"
        log "On Ubuntu, install with: sudo apt-get install -y xorriso squashfs-tools"
        exit 1
    fi
done

log_success "All required tools found"

# Cleanup function
cleanup() {
    log_warning "Cleaning up temporary files..."
    if [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
        log_success "Cleanup complete"
    fi
}

trap cleanup EXIT

# Create working directory
log "Creating working directory..."
mkdir -p "$WORK_DIR"/{iso,rootfs}

# Extract ISO
log "Extracting ISO (this may take a minute)..."
xorriso -osirrox on -indev "$UBUNTU_ISO" -extract / "$WORK_DIR/iso" 2>&1 | grep -v "^I:" || true
log_success "ISO extracted"

# Extract filesystem
log "Extracting squashfs root filesystem..."
if [ -f "$WORK_DIR/iso/casper/filesystem.squashfs" ]; then
    unsquashfs -d "$WORK_DIR/rootfs" "$WORK_DIR/iso/casper/filesystem.squashfs" > /dev/null 2>&1
    log_success "Root filesystem extracted"
else
    log_error "filesystem.squashfs not found - may be different Ubuntu version"
    exit 1
fi

# Inject cloud-init nocloud files
log "Injecting cloud-init nocloud files..."
mkdir -p "$WORK_DIR/iso/nocloud"
cp "$SCRIPT_DIR/nocloud/user-data" "$WORK_DIR/iso/nocloud/"
cp "$SCRIPT_DIR/nocloud/meta-data" "$WORK_DIR/iso/nocloud/"
log_success "Nocloud files injected"

# Inject scripts into ISO
log "Injecting scripts..."
mkdir -p "$WORK_DIR/iso/scripts"
cp "$SCRIPT_DIR/scripts/ubuntu-ultimate-optimization.sh" "$WORK_DIR/iso/scripts/"
cp "$SCRIPT_DIR/scripts/first-boot.sh" "$WORK_DIR/iso/scripts/"
cp "$SCRIPT_DIR/scripts/run-all.sh" "$WORK_DIR/iso/scripts/"
chmod +x "$WORK_DIR/iso/scripts"/*.sh
log_success "Scripts injected"

# Inject systemd service
log "Injecting systemd service..."
mkdir -p "$WORK_DIR/iso/units"
cp "$SCRIPT_DIR/units/first-boot.service" "$WORK_DIR/iso/units/"
log_success "Service unit injected"

# Repack squashfs (if needed, otherwise just copy as-is)
log "Repacking root filesystem..."
if [ -d "$WORK_DIR/rootfs" ]; then
    mksquashfs "$WORK_DIR/rootfs" "$WORK_DIR/iso/casper/filesystem.squashfs" -b 1048576 > /dev/null 2>&1
    log_success "Root filesystem repacked"
fi

# Rebuild ISO
log "Building new ISO (this may take a few minutes)..."
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "Ubuntu Autoinstall" \
    -eltorito-boot boot/grub/i386-pc/eltorito.img \
    -eltorito-catalog boot/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e EFI/boot/bootx64.efi \
    -no-emul-boot \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -isohybrid-gpt-basdat \
    -R \
    -J \
    -o "$OUTPUT_ISO" \
    "$WORK_DIR/iso" 2>&1 | tail -5

log_success "ISO built successfully: $OUTPUT_ISO"

# Verify ISO
log "Verifying ISO..."
if file "$OUTPUT_ISO" | grep -q "ISO 9660"; then
    log_success "ISO is valid"
    log_success "Size: $(du -h "$OUTPUT_ISO" | cut -f1)"

    log ""
    log_success "=== ISO Build Complete ==="
    log "Output: $OUTPUT_ISO"
    log ""
    log "Next steps:"
    log "1. Write to USB with dd or Rufus:"
    log "   sudo dd if=$OUTPUT_ISO of=/dev/sdX bs=4M status=progress oflag=sync"
    log "   OR use Rufus in DD Image mode on Windows"
    log ""
    log "2. Boot from USB and wait for:"
    log "   - Automatic installation to complete"
    log "   - System reboot"
    log "   - First-boot optimization service to run"
    log ""
else
    log_error "ISO verification failed"
    exit 1
fi
