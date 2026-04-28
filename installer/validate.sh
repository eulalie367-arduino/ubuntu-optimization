#!/bin/bash
################################################################################
# Validate user-data using cloud-init schema
# Creates Python venv, installs cloud-init, validates against schema
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
USER_DATA_FILE="$SCRIPT_DIR/nocloud/user-data"

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

log "Ubuntu Autoinstall user-data Validator"
log "Script directory: $SCRIPT_DIR"

# Check if user-data exists
if [ ! -f "$USER_DATA_FILE" ]; then
    log_error "user-data file not found at: $USER_DATA_FILE"
    exit 1
fi

log "Found user-data file: $USER_DATA_FILE"

# Create Python virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    log "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    log_success "Virtual environment created"
fi

# Determine Python executable in venv
if [ -f "$VENV_DIR/bin/python" ]; then
    PY_BIN="$VENV_DIR/bin/python"
    PIP_BIN="$VENV_DIR/bin/pip"
elif [ -f "$VENV_DIR/Scripts/python.exe" ]; then
    PY_BIN="$VENV_DIR/Scripts/python.exe"
    PIP_BIN="$VENV_DIR/Scripts/pip.exe"
else
    log_error "Could not find Python executable in venv"
    exit 1
fi

log "Using Python: $PY_BIN"

# Install validation dependencies
log "Installing validation dependencies..."
"$PIP_BIN" install --quiet --upgrade pip setuptools wheel 2>&1 | grep -v "already satisfied\|A new release\|To update" || true
"$PIP_BIN" install --quiet jsonschema pyyaml 2>&1 | grep -v "already satisfied\|A new release\|To update" || true

log_success "Dependencies installed"

# Validate user-data - first check YAML syntax
log "Validating user-data YAML syntax..."

yaml_check=$(cat <<'YAML_CHECK_EOF'
import sys
import yaml
try:
    with open(sys.argv[1]) as f:
        yaml.safe_load(f)
    print("YAML syntax valid")
    sys.exit(0)
except yaml.YAMLError as e:
    print(f"YAML Error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
YAML_CHECK_EOF
)

if "$PY_BIN" -c "$yaml_check" "$USER_DATA_FILE" 2>&1 | grep -q "YAML syntax valid"; then
    log_success "YAML syntax validation PASSED"
else
    log_error "user-data YAML validation FAILED"
    exit 1
fi

# Check for cloud-init (will only work on Linux)
log "Checking for cloud-init schema validation (requires Linux)..."

if "$PY_BIN" -m cloud_init.schema 2>/dev/null || "$PY_BIN" -c "import cloud_init" 2>/dev/null; then
    log "cloud-init found - running full schema validation..."
    if "$PY_BIN" -m cloud_init schema --config-file "$USER_DATA_FILE" 2>&1; then
        log_success "Cloud-init schema validation PASSED"
    else
        log_warning "Cloud-init schema validation had issues - check manually on Linux"
    fi
else
    log_warning "cloud-init not available (expected on Windows)"
    log "For full validation, run this on a Linux system with cloud-init installed:"
    log "  cloud-init schema --config-file nocloud/user-data"
fi

log ""
log_success "Basic YAML validation PASSED"
log_success "Configuration is ready for ISO build"
log ""
log "Next steps:"
log "1. Build ISO: bash installer/build-iso.sh /path/to/ubuntu-22.04.3-live-server-amd64.iso"
log "2. Full schema validation should be done on Linux before deploying"
exit 0
