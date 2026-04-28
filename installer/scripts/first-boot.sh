#!/bin/bash
################################################################################
# First-Boot Wrapper Script
# Waits for network, runs optimization, handles failures gracefully
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SENTINEL_FILE="/etc/first-boot-needed"
LOG_DIR="/var/log/ubuntu-optimization"
LOG_FILE="$LOG_DIR/first-boot.log"
MAX_RETRIES=12
RETRY_INTERVAL=10
NETWORK_CHECK_ADDR="8.8.8.8"

# Create log directory
mkdir -p "$LOG_DIR"

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✓ $*${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}✗ $*${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠ $*${NC}" | tee -a "$LOG_FILE"
}

log "=== First-Boot Optimization Service Started ==="
log "PID: $$"
log "Time: $(date)"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Check sentinel file
if [ ! -f "$SENTINEL_FILE" ]; then
    log "Sentinel file not found - optimization already completed or not needed"
    exit 0
fi

log "Sentinel file found - starting optimization pipeline"

# Wait for network to come up
log "Waiting for network connectivity..."
retry_count=0

while [ $retry_count -lt $MAX_RETRIES ]; do
    if ping -c 1 -W 2 "$NETWORK_CHECK_ADDR" &>/dev/null; then
        log_success "Network is online"
        break
    fi

    retry_count=$((retry_count + 1))
    log_warning "Network offline (attempt $retry_count/$MAX_RETRIES), retrying in ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
done

if [ $retry_count -ge $MAX_RETRIES ]; then
    log_error "Network did not come online after $((MAX_RETRIES * RETRY_INTERVAL))s"
    log_warning "Sentinel file preserved - will retry on next boot"
    exit 1
fi

# Run the optimization pipeline
log "Starting optimization pipeline..."
optimization_cmd="/usr/local/bin/run-all.sh --phase 1 --phase 2 --backup"

if bash "$optimization_cmd" 2>&1 | tee -a "$LOG_FILE"; then
    log_success "Optimization completed successfully"

    # Remove sentinel and disable service
    if rm -f "$SENTINEL_FILE"; then
        log_success "Removed sentinel file"
    fi

    # Disable this service so it doesn't run again
    if systemctl disable first-boot.service 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Disabled first-boot.service"
    fi

    # Remove the service unit file
    if rm -f /etc/systemd/system/first-boot.service; then
        log_success "Removed first-boot.service unit"
        systemctl daemon-reload
    fi

    log_success "First-boot optimization complete - service will not run again"
    exit 0
else
    log_error "Optimization failed - check logs"
    log_warning "Sentinel file preserved - will retry on next boot"
    exit 1
fi
