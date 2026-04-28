#!/bin/bash

################################################################################
# Ubuntu Ultimate Optimization Script (2025)
# Combines: System Hardening + Performance Optimization + Kernel Customization
#
# Usage: sudo bash ubuntu-ultimate-optimization.sh [OPTIONS]
# OPTIONS:
#   --phase 1          Run Phase 1 only (recommended first)
#   --phase 2          Run Phase 2 only
#   --phase 3          Run Phase 3 only
#   --security         Run security-focused changes
#   --performance      Run performance-focused changes
#   --kernel           Run kernel compilation/optimization
#   --all              Run everything (not recommended first time)
#   --dry-run          Show what would be done without making changes
#   --backup           Create backups before changes
#
# Examples:
#   sudo bash ubuntu-ultimate-optimization.sh --phase 1
#   sudo bash ubuntu-ultimate-optimization.sh --security --performance
#   sudo bash ubuntu-ultimate-optimization.sh --backup --phase 1
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script settings
DRY_RUN=false
CREATE_BACKUP=false
PHASE_1=false
PHASE_2=false
PHASE_3=false
RUN_SECURITY=false
RUN_PERFORMANCE=false
RUN_KERNEL=false
RUN_ALL=false

# Logging
LOG_DIR="/var/log/ubuntu-optimization"
LOG_FILE="$LOG_DIR/optimization-$(date +%Y%m%d-%H%M%S).log"

################################################################################
# UTILITY FUNCTIONS
################################################################################

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

run_command() {
    local cmd="$1"
    local description="${2:-Running: $cmd}"

    log "$description"

    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY RUN] Would execute: $cmd"
        return 0
    fi

    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        log_success "Completed: $description"
    else
        log_error "Failed: $description"
        return 1
    fi
}

backup_file() {
    local file="$1"
    local backup_dir="/var/backups/ubuntu-optimization-$(date +%Y%m%d-%H%M%S)"

    if [ ! -f "$file" ]; then
        log_warning "File not found for backup: $file"
        return 0
    fi

    mkdir -p "$backup_dir"
    cp -v "$file" "$backup_dir/" 2>&1 | tee -a "$LOG_FILE"
    log_success "Backed up: $file → $backup_dir"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_ubuntu() {
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "This script is designed for Ubuntu systems"
        exit 1
    fi

    UBUNTU_VERSION=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    log "Detected Ubuntu $UBUNTU_VERSION"
}

################################################################################
# PHASE 1: IMMEDIATE HIGH-IMPACT CHANGES (Safe, Quick)
################################################################################

phase_1_security() {
    log "\n${BLUE}=== PHASE 1: Security Hardening ===${NC}"

    # 1. Setup UFW Firewall
    log_warning "Setting up UFW Firewall..."
    run_command "apt-get update" "Update package lists"
    run_command "apt-get install -y ufw" "Install UFW"

    if [ "$DRY_RUN" = false ]; then
        # Critical: Allow SSH before enabling firewall
        ufw default deny incoming 2>&1 | tee -a "$LOG_FILE"
        ufw default allow outgoing 2>&1 | tee -a "$LOG_FILE"
        ufw allow 22/tcp 2>&1 | tee -a "$LOG_FILE"
        ufw allow 80/tcp 2>&1 | tee -a "$LOG_FILE"
        ufw allow 443/tcp 2>&1 | tee -a "$LOG_FILE"
        echo "y" | ufw enable 2>&1 | tee -a "$LOG_FILE"
        log_success "UFW Firewall enabled"
    else
        log_warning "[DRY RUN] Would configure UFW firewall"
    fi

    # 2. Setup Fail2Ban
    log_warning "Setting up Fail2Ban..."
    run_command "apt-get install -y fail2ban" "Install Fail2Ban"

    if [ "$DRY_RUN" = false ]; then
        [ "$CREATE_BACKUP" = true ] && backup_file "/etc/fail2ban/jail.conf"

        cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
findtime = 600
maxretry = 5
bantime = 600
destemail = root@localhost
sender = noreply@localhost

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

        systemctl enable fail2ban 2>&1 | tee -a "$LOG_FILE"
        systemctl restart fail2ban 2>&1 | tee -a "$LOG_FILE"
        log_success "Fail2Ban configured and enabled"
    fi

    # 3. Harden SSH
    log_warning "Hardening SSH..."
    [ "$CREATE_BACKUP" = true ] && backup_file "/etc/ssh/sshd_config"

    if [ "$DRY_RUN" = false ]; then
        cat > /etc/ssh/sshd_config.d/99-hardening.conf << 'EOF'
# SSH Hardening
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
MaxSessions 2
X11Forwarding no
AllowTcpForwarding no
PermitEmptyPasswords no
StrictModes yes
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
LogLevel VERBOSE
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

        sshd -t 2>&1 | tee -a "$LOG_FILE"
        systemctl restart ssh 2>&1 | tee -a "$LOG_FILE"
        log_success "SSH hardened"
    fi

    # 4. Disable unnecessary services
    log_warning "Disabling unnecessary services..."
    local services_to_disable=("avahi-daemon" "bluetooth" "cups" "snapd")

    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null 2>&1; then
            run_command "systemctl disable --now $service" "Disable $service"
        fi
    done

    log_success "Phase 1 Security changes complete"
}

phase_1_performance() {
    log "\n${BLUE}=== PHASE 1: Performance Optimization ===${NC}"

    # 1. Configure swap and zswap
    log_warning "Configuring swap and zswap..."

    if [ "$DRY_RUN" = false ]; then
        [ "$CREATE_BACKUP" = true ] && backup_file "/etc/sysctl.conf"

        cat >> /etc/sysctl.d/99-optimization.conf << 'EOF'
# Swap Management
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=15
vm.dirty_background_ratio=5
vm.min_free_kbytes=131072

# zswap Configuration
vm.max_map_count=262144
EOF

        sysctl -p /etc/sysctl.d/99-optimization.conf 2>&1 | tee -a "$LOG_FILE"

        # Enable zswap
        echo 1 > /sys/module/zswap/parameters/enabled
        echo lz4 > /sys/module/zswap/parameters/compressor
        echo 20 > /sys/module/zswap/parameters/max_pool_percent

        log_success "Swap and zswap configured"
    fi

    # 2. Setup automatic TRIM
    log_warning "Enabling SSD TRIM..."
    run_command "systemctl enable --now fstrim.timer" "Enable fstrim timer"

    # 3. Mount options optimization
    log_warning "Optimizing mount options..."
    if [ "$DRY_RUN" = false ]; then
        [ "$CREATE_BACKUP" = true ] && backup_file "/etc/fstab"

        # Show current mounts that could be optimized
        log "Current mount points (for reference):"
        mount | grep -E "ext4|btrfs|xfs" | tee -a "$LOG_FILE"
        log "Note: Manually update /etc/fstab to add noatime for better performance"
    fi

    # 4. Disable transparent huge pages if needed
    log_warning "Checking Transparent Huge Pages..."
    if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
        current_thp=$(cat /sys/kernel/mm/transparent_hugepage/enabled)
        log "Current THP setting: $current_thp"

        if [ "$DRY_RUN" = false ]; then
            # Set to madvise for selective use
            echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
            log_success "THP set to madvise mode"
        fi
    fi

    log_success "Phase 1 Performance changes complete"
}

################################################################################
# PHASE 2: COMPREHENSIVE SYSTEM TUNING (Moderate Changes)
################################################################################

phase_2_security() {
    log "\n${BLUE}=== PHASE 2: Advanced Security ===${NC}"

    # 1. Setup auditd
    log_warning "Configuring auditd..."
    run_command "apt-get install -y auditd audispd-plugins" "Install auditd"

    if [ "$DRY_RUN" = false ]; then
        [ "$CREATE_BACKUP" = true ] && backup_file "/etc/audit/rules.d/audit.rules"

        cat > /etc/audit/rules.d/99-ubuntu-optimization.rules << 'EOF'
# Remove any existing rules
-D

# Buffer Size
-b 8192

# Failure Mode
-f 1

# Monitor sudoers changes
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers_d

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes

# Monitor user/group changes
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity

# Monitor authentication
-w /var/log/auth.log -p wa -k auth_log

# Monitor system administration
-w /var/log/audit/ -k auditlog

# Make configuration immutable
-e 2
EOF

        auditctl -R /etc/audit/rules.d/99-ubuntu-optimization.rules 2>&1 | tee -a "$LOG_FILE"
        systemctl enable auditd 2>&1 | tee -a "$LOG_FILE"
        systemctl restart auditd 2>&1 | tee -a "$LOG_FILE"
        log_success "auditd configured"
    fi

    # 2. Harden sudo
    log_warning "Hardening sudo configuration..."
    if [ "$DRY_RUN" = false ]; then
        [ "$CREATE_BACKUP" = true ] && backup_file "/etc/sudoers"

        cat > /etc/sudoers.d/99-hardening << 'EOF'
# Sudo Hardening
Defaults use_pty
Defaults log_output
Defaults logfile="/var/log/sudo/sudo.log"
Defaults requiretty
Defaults passwd_timeout=1
Defaults lecture="once"
EOF

        chmod 440 /etc/sudoers.d/99-hardening
        mkdir -p /var/log/sudo
        visudo -c 2>&1 | tee -a "$LOG_FILE"
        log_success "sudo hardened"
    fi

    # 3. Setup automatic security updates
    log_warning "Configuring automatic security updates..."
    run_command "apt-get install -y unattended-upgrades apt-listchanges" "Install unattended-upgrades"

    if [ "$DRY_RUN" = false ]; then
        [ "$CREATE_BACKUP" = true ] && backup_file "/etc/apt/apt.conf.d/50unattended-upgrades"

        cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};

Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "on-change";
EOF

        systemctl enable unattended-upgrades 2>&1 | tee -a "$LOG_FILE"
        systemctl restart unattended-upgrades 2>&1 | tee -a "$LOG_FILE"
        log_success "Automatic security updates configured"
    fi

    log_success "Phase 2 Security changes complete"
}

phase_2_performance() {
    log "\n${BLUE}=== PHASE 2: Advanced Performance Tuning ===${NC}"

    # 1. Configure CPU frequency scaling
    log_warning "Setting up CPU frequency scaling..."
    run_command "apt-get install -y linux-tools-generic cpufrequtils" "Install CPU frequency tools"

    if [ "$DRY_RUN" = false ]; then
        # Set governor to schedutil (modern best practice)
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "schedutil" > "$cpu" 2>/dev/null || true
        done
        log_success "CPU governor set to schedutil"
    fi

    # 2. Optimize I/O scheduler
    log_warning "Optimizing I/O scheduler..."
    if [ "$DRY_RUN" = false ]; then
        # Detect storage type
        if grep -q "nvme" /proc/partitions; then
            log "NVMe detected - using 'none' scheduler"
            echo none > /sys/block/nvme0n1/queue/scheduler 2>/dev/null || true
        elif lsblk -d -o ROTA | grep -q 0; then
            log "SSD detected - using 'bfq' scheduler"
            echo bfq > /sys/block/sda/queue/scheduler 2>/dev/null || true
        else
            log "HDD detected - using 'mq-deadline' scheduler"
            echo mq-deadline > /sys/block/sda/queue/scheduler 2>/dev/null || true
        fi
        log_success "I/O scheduler optimized"
    fi

    # 3. Network tuning
    log_warning "Optimizing network parameters..."
    if [ "$DRY_RUN" = false ]; then
        [ "$CREATE_BACKUP" = true ] && backup_file "/etc/sysctl.conf"

        cat >> /etc/sysctl.d/99-network-optimization.conf << 'EOF'
# Network Optimization
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
net.ipv4.tcp_max_syn_backlog=4096
net.core.somaxconn=4096
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30
EOF

        sysctl -p /etc/sysctl.d/99-network-optimization.conf 2>&1 | tee -a "$LOG_FILE"
        log_success "Network parameters optimized"
    fi

    # 4. Analyze and optimize boot time
    log_warning "Analyzing boot performance..."
    if [ "$DRY_RUN" = false ]; then
        systemd-analyze 2>&1 | tee -a "$LOG_FILE"
        log "Run 'systemd-analyze blame' to see slowest services"
    fi

    log_success "Phase 2 Performance changes complete"
}

################################################################################
# PHASE 3: ADVANCED KERNEL CUSTOMIZATION (Requires Compilation)
################################################################################

phase_3_kernel() {
    log "\n${BLUE}=== PHASE 3: Kernel Customization ===${NC}"

    log_warning "This phase involves kernel compilation. Estimated time: 30 mins - 3 hours"
    log "Checking prerequisites..."

    # Check disk space
    available_space=$(df /usr/src | awk 'NR==2 {print $4}')
    required_space=$((30 * 1024 * 1024)) # 30GB in KB

    if [ "$available_space" -lt "$required_space" ]; then
        log_error "Insufficient disk space. Required: 30GB, Available: $((available_space/1024/1024))GB"
        return 1
    fi

    # Install build dependencies
    log_warning "Installing build dependencies..."
    run_command "apt-get install -y build-essential libncurses-dev bison flex libssl-dev libelf-dev git" \
        "Install kernel build dependencies"

    if [ "$DRY_RUN" = false ]; then
        # Download kernel source (using Ubuntu kernel)
        log_warning "Downloading kernel source..."
        cd /usr/src || exit 1

        # Get current kernel version
        current_kernel=$(uname -r | cut -d'-' -f1)
        log "Current kernel: $current_kernel"
        log "Note: Download and compile in /usr/src/linux-*"
        log "Run: make menuconfig, make -j\$(nproc) bindeb-pkg, sudo dpkg -i linux-*.deb"
    fi

    log_warning "Kernel compilation setup complete. Manual steps required:"
    log "1. Download kernel source from kernel.org"
    log "2. Run 'make menuconfig' to configure"
    log "3. Recommended options:"
    log "   - CONFIG_PREEMPT_DYNAMIC or CONFIG_PREEMPT_NONE (for servers)"
    log "   - CONFIG_CPU_FREQ_SCALING=y"
    log "   - CONFIG_HAVE_EFFICIENT_UNALIGNED_ACCESS=y"
    log "   - Keep security mitigations enabled"
    log "4. Compile: make -j\$(nproc) bindeb-pkg"
    log "5. Install: sudo dpkg -i linux-image-*.deb linux-headers-*.deb"

    log_success "Phase 3 setup complete"
}

################################################################################
# HEALTH CHECKS & VERIFICATION
################################################################################

health_check() {
    log "\n${BLUE}=== System Health Check ===${NC}"

    log "Checking security status..."

    # UFW status
    if systemctl is-active ufw &>/dev/null; then
        log_success "UFW Firewall: ACTIVE"
        ufw status | head -5 | tee -a "$LOG_FILE"
    else
        log_warning "UFW Firewall: INACTIVE"
    fi

    # Fail2Ban status
    if systemctl is-active fail2ban &>/dev/null; then
        log_success "Fail2Ban: ACTIVE"
    else
        log_warning "Fail2Ban: INACTIVE"
    fi

    # SSH hardening check
    if grep -q "PermitRootLogin no" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null; then
        log_success "SSH: Root login disabled"
    else
        log_warning "SSH: Root login may not be disabled"
    fi

    # auditd status
    if systemctl is-active auditd &>/dev/null; then
        log_success "auditd: ACTIVE"
    else
        log_warning "auditd: INACTIVE"
    fi

    log "\nPerformance status..."

    # Swap info
    free -h | tee -a "$LOG_FILE"

    # I/O scheduler
    log "Current I/O scheduler:"
    cat /sys/block/*/queue/scheduler 2>/dev/null | head -1 | tee -a "$LOG_FILE"

    # CPU governor
    log "Current CPU governor:"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null | tee -a "$LOG_FILE"

    # Sysctl optimization
    log "Key sysctl parameters:"
    sysctl vm.swappiness net.ipv4.tcp_congestion_control 2>/dev/null | tee -a "$LOG_FILE"

    log_success "Health check complete"
}

################################################################################
# PARSE ARGUMENTS
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --phase)
                case $2 in
                    1) PHASE_1=true ;;
                    2) PHASE_2=true ;;
                    3) PHASE_3=true ;;
                    *) log_error "Invalid phase: $2"; exit 1 ;;
                esac
                shift 2
                ;;
            --security)
                RUN_SECURITY=true
                shift
                ;;
            --performance)
                RUN_PERFORMANCE=true
                shift
                ;;
            --kernel)
                RUN_KERNEL=true
                shift
                ;;
            --all)
                PHASE_1=true
                PHASE_2=true
                PHASE_3=true
                RUN_SECURITY=true
                RUN_PERFORMANCE=true
                RUN_KERNEL=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --backup)
                CREATE_BACKUP=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Default to Phase 1 if nothing specified
    if [ "$PHASE_1" = false ] && [ "$PHASE_2" = false ] && [ "$PHASE_3" = false ] && \
       [ "$RUN_SECURITY" = false ] && [ "$RUN_PERFORMANCE" = false ] && [ "$RUN_KERNEL" = false ]; then
        log_warning "No specific phase selected. Using Phase 1 (safe defaults)"
        PHASE_1=true
        RUN_SECURITY=true
        RUN_PERFORMANCE=true
    fi
}

show_help() {
    cat << EOF
Ubuntu Ultimate Optimization Script (2025)

USAGE:
    sudo bash ubuntu-ultimate-optimization.sh [OPTIONS]

OPTIONS:
    --phase 1               Run Phase 1 only (Recommended for first run)
    --phase 2               Run Phase 2 only (Advanced tuning)
    --phase 3               Run Phase 3 only (Kernel compilation)
    --security              Run security hardening
    --performance           Run performance optimization
    --kernel                Run kernel customization
    --all                   Run everything (not recommended first time)
    --dry-run               Show what would be done without making changes
    --backup                Create backups before modifying files
    --help                  Show this help message

EXAMPLES:
    # Recommended first run
    sudo bash ubuntu-ultimate-optimization.sh --phase 1 --backup

    # Full hardening
    sudo bash ubuntu-ultimate-optimization.sh --security --backup

    # Full performance optimization
    sudo bash ubuntu-ultimate-optimization.sh --performance --backup

    # Preview changes
    sudo bash ubuntu-ultimate-optimization.sh --phase 1 --dry-run

    # Everything with backups
    sudo bash ubuntu-ultimate-optimization.sh --all --backup

PHASES:
    Phase 1 (30 mins)    - Immediate high-impact changes (firewall, SSH, swap)
    Phase 2 (1 hour)     - Advanced security and performance tuning
    Phase 3 (2-3 hours)  - Kernel compilation and customization

BACKUPS:
    All backups stored in: /var/backups/ubuntu-optimization-<timestamp>/

LOG FILE:
    $LOG_FILE

EOF
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    check_root
    check_ubuntu

    # Create log directory
    mkdir -p "$LOG_DIR"

    log "================================"
    log "Ubuntu Ultimate Optimization"
    log "================================"
    log "Start time: $(date)"
    log "Dry run: $DRY_RUN"
    log "Create backups: $CREATE_BACKUP"

    # Execute requested phases
    if [ "$PHASE_1" = true ]; then
        if [ "$RUN_SECURITY" = true ] || [ "$RUN_PERFORMANCE" = true ] || [ "$RUN_SECURITY" = false ] && [ "$RUN_PERFORMANCE" = false ]; then
            [ "$RUN_SECURITY" != false ] && phase_1_security
            [ "$RUN_PERFORMANCE" != false ] && phase_1_performance
        fi
    fi

    if [ "$PHASE_2" = true ]; then
        log_warning "Phase 2 requires Phase 1 to be completed first"
        if [ "$RUN_SECURITY" = true ] || [ "$RUN_PERFORMANCE" = true ] || [ "$RUN_SECURITY" = false ] && [ "$RUN_PERFORMANCE" = false ]; then
            [ "$RUN_SECURITY" != false ] && phase_2_security
            [ "$RUN_PERFORMANCE" != false ] && phase_2_performance
        fi
    fi

    if [ "$PHASE_3" = true ] || [ "$RUN_KERNEL" = true ]; then
        phase_3_kernel
    fi

    # Run health check
    health_check

    # Summary
    log "\n================================"
    log "Optimization Complete!"
    log "================================"
    log "Log file: $LOG_FILE"

    if [ "$DRY_RUN" = true ]; then
        log_warning "This was a dry run. No changes were made."
        log "Re-run without --dry-run to apply changes."
    fi

    if [ "$CREATE_BACKUP" = true ]; then
        log "Backups created in /var/backups/"
    fi

    log "End time: $(date)"
}

parse_arguments "$@"
main

