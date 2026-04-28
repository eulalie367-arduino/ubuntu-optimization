#!/bin/bash
################################################################################
# Ubuntu Optimization Orchestrator
# Calls all phase scripts in sequence with proper error handling
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_DIR="/var/log/ubuntu-optimization"
LOG_FILE="$LOG_DIR/first-boot-$(date +%Y%m%d-%H%M%S).log"

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

log "Starting Ubuntu Optimization Pipeline"
log "Log file: $LOG_FILE"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Parse command-line arguments
PHASES=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --phase)
            PHASES+=("$2")
            shift 2
            ;;
        --backup)
            BACKUP_FLAG="--backup"
            shift
            ;;
        *)
            log_warning "Unknown option: $1"
            shift
            ;;
    esac
done

# Default to phases 1 and 2 if none specified
if [ ${#PHASES[@]} -eq 0 ]; then
    PHASES=(1 2)
fi

log "Running phases: ${PHASES[@]}"

# Run optimization script with selected phases
optimization_script="/usr/local/bin/ubuntu-ultimate-optimization.sh"

if [ ! -f "$optimization_script" ]; then
    log_error "Optimization script not found: $optimization_script"
    exit 1
fi

# Build phase arguments
phase_args=""
for phase in "${PHASES[@]}"; do
    phase_args="$phase_args --phase $phase"
done

# Add backup flag if set
if [ -n "${BACKUP_FLAG:-}" ]; then
    phase_args="$phase_args --backup"
fi

log "Executing: sudo bash $optimization_script $phase_args"

if sudo bash "$optimization_script" $phase_args 2>&1 | tee -a "$LOG_FILE"; then
    log_success "Optimization pipeline completed successfully"
    exit 0
else
    log_error "Optimization pipeline failed - check logs above"
    exit 1
fi
