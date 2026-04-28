# Ubuntu Autoinstall Bootable USB Builder

This directory contains everything needed to create a bootable Ubuntu USB that:
- **Fully automates** installation with cloud-init autoinstall
- **Configures** partitions, users, SSH, and network automatically
- **Runs optimization** on first boot via systemd service
- **Applies** Phase 1 & 2 optimizations (security + performance)

## Quick Start

### Prerequisites

- Ubuntu 22.04.3 LTS ISO (`ubuntu-22.04.3-live-server-amd64.iso`)
- On Linux/WSL: `xorriso`, `squashfs-tools`
  ```bash
  sudo apt-get install -y xorriso squashfs-tools
  ```
- On Windows: Rufus for burning to USB (in DD Image mode)

### Step 1: Validate Configuration

```bash
cd E:/migration/installer
bash validate.sh
```

Output should show: ✓ Basic YAML validation PASSED

### Step 2: Build the ISO

```bash
bash build-iso.sh /path/to/ubuntu-22.04.3-live-server-amd64.iso
```

This creates: `ubuntu-optimized-autoinstall.iso`

### Step 3: Write to USB

**On Linux/WSL:**
```bash
sudo dd if=ubuntu-optimized-autoinstall.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

**On Windows:**
- Download [Rufus](https://rufus.ie/)
- Select the ISO, choose **DD Image** mode, burn to USB

### Step 4: Boot and Wait

1. Plug USB into target machine
2. Boot from USB
3. Installer runs automatically (~5-10 minutes)
4. System reboots
5. First-boot service runs optimization (~15-30 minutes)
6. Done!

## Directory Structure

```
installer/
├── nocloud/
│   ├── user-data          ← Autoinstall + first-boot config
│   └── meta-data          ← Required empty file
├── scripts/
│   ├── run-all.sh         ← Orchestrator (runs phases 1 & 2)
│   ├── first-boot.sh      ← Network-aware wrapper
│   └── ubuntu-ultimate-optimization.sh  ← Main optimization script
├── units/
│   └── first-boot.service ← Systemd oneshot service
├── validate.sh            ← Validates user-data YAML
├── build-iso.sh           ← Builds custom ISO
└── README.md              ← This file
```

## What Gets Installed

### Base System
- Ubuntu 22.04 LTS (Jammy)
- Hostname: `ubuntu-optimized`
- User: `ubuntu` (SSH keys only, no password login)

### Partitioning
- 2 GB EFI (`/boot/efi`)
- 2 GB `/boot`
- 30 GB `/`
- 50 GB `/usr/src` (kernel compilation space)
- 20 GB `/var`
- Remaining space → `/home`

### Packages
- `openssh-server`, `curl`, `wget`, `git`, `vim`
- Build tools: `build-essential`, `python3-dev`, `libssl-dev`
- Monitoring: `htop`, `iotop`, `sysstat`, `tmux`

### Phase 1: Security
- UFW firewall (SSH, HTTP, HTTPS allowed)
- Fail2Ban (SSH bruteforce protection)
- SSH hardening (key-only, strong ciphers)
- Disable: avahi, bluetooth, cups, snapd

### Phase 1: Performance
- Swap optimization (`vm.swappiness=10`)
- zswap compression (`lz4`)
- SSD TRIM (auto `fstrim.timer`)
- Transparent Huge Pages → madvise mode

### Phase 2: Security
- auditd (system call auditing)
- Sudo hardening (pty, logging)
- Automatic security updates (unattended-upgrades)

### Phase 2: Performance
- CPU frequency scaling (schedutil governor)
- I/O scheduler optimization (NVMe/SSD/HDD auto-detection)
- Network tuning (BBR congestion control, buffer optimization)
- Boot time analysis (systemd-analyze)

## Customization

### Edit User & SSH Key

Edit `nocloud/user-data`:

```yaml
identity:
  hostname: ubuntu-optimized
  username: ubuntu
  password: $6$...hashed-password...  # Use `openssl passwd -6` to generate

ssh:
  allowed-ssh:
    - public-keys:
        - "ssh-rsa AAAA... your-actual-ssh-public-key ..."
```

### Change Partitioning

Edit `nocloud/user-data` storage section:

```yaml
storage:
  disks:
    - device: /dev/sda
      partitions:
        - size: 2147483648  # 2GB in bytes
          format: ext4
          mount: /boot
        # ... etc
```

### Skip First-Boot Optimization

Comment out in `nocloud/user-data` late-commands:

```yaml
late-commands:
  # - touch /target/etc/first-boot-needed  # Comment this out
  # - curtin in-target systemctl enable first-boot.service
```

### Enable Phase 3 (Kernel Compilation)

Edit `/target/usr/local/bin/run-all.sh` after boot and manually run:

```bash
sudo bash /usr/local/bin/ubuntu-ultimate-optimization.sh --phase 3 --backup
```

(Phase 3 is intentionally skipped by default - takes 1-3 hours)

## Troubleshooting

### Validation Fails: "YAML syntax validation FAILED"

Check `nocloud/user-data` for YAML errors:
- Indentation must be 2 spaces (not tabs)
- Colons need space after: `key: value`
- Strings with special chars need quotes: `"value with : colon"`

### ISO Build Fails: "xorriso not found"

Install tools:
```bash
sudo apt-get install -y xorriso squashfs-tools
```

### First-Boot Service Doesn't Run

Check logs after reboot:
```bash
journalctl -u first-boot.service -n 50
tail -f /var/log/ubuntu-optimization/first-boot.log
```

If sentinel file exists, service will retry on next boot:
```bash
ls -la /etc/first-boot-needed
```

### Network Connectivity Issues During First-Boot

Service waits up to 120 seconds for network. Check:
```bash
journalctl -u network-online.target
ip addr show
```

## Full Deployment Flow

```
1. User runs: bash build-iso.sh ubuntu-22.04.3.iso
   ↓
2. xorriso extracts ISO, injects installer/ files
   ↓
3. ISO is burned to USB (dd or Rufus)
   ↓
4. Machine boots from USB
   ↓
5. cloud-init subiquity reads user-data from /cdrom/nocloud/
   ↓
6. Unattended installation runs
   ↓
7. Scripts are copied from /cdrom/scripts/ to /target/usr/local/bin/
   ↓
8. first-boot.service is enabled
   ↓
9. Sentinel file (/etc/first-boot-needed) is created
   ↓
10. System reboots
   ↓
11. first-boot.service waits for network (120s max)
   ↓
12. Runs: /usr/local/bin/run-all.sh --phase 1 --phase 2 --backup
   ↓
13. Optimization completes, sentinel removed, service disabled
   ↓
14. System is ready with all optimizations applied
```

## Files to Review

- **user-data**: Cloud-init autoinstall + late-commands
- **first-boot.sh**: Network-aware wrapper with retry logic
- **run-all.sh**: Phase orchestrator
- **ubuntu-ultimate-optimization.sh**: Main optimization script (3 phases)
- **first-boot.service**: Systemd service unit

## Logs

After installation, check these logs:

```bash
# Autoinstall logs
less /var/log/subiquity/
cat /var/log/cloud-init-output.log

# First-boot optimization
cat /var/log/ubuntu-optimization/first-boot.log
cat /var/log/ubuntu-optimization/optimization-*.log

# Systemd service
journalctl -u first-boot.service
journalctl -u network-online.target
```

## Advanced: Manual Kernel Compilation (Phase 3)

Phase 3 is skipped on first boot but can be run manually:

```bash
sudo bash /usr/local/bin/ubuntu-ultimate-optimization.sh --phase 3 --backup --dry-run
# Review what would happen, then:
sudo bash /usr/local/bin/ubuntu-ultimate-optimization.sh --phase 3 --backup
```

This requires:
- 30+ GB disk space (in `/usr/src`)
- 1-3 hours compilation time
- 4+ CPU cores recommended

## Security Notes

- Default user: `ubuntu` (no password)
- SSH: keys only (`allow-pw: false`)
- Firewall: UFW enabled, SSH/HTTP/HTTPS allowed
- Fail2Ban: SSH bruteforce protection enabled
- Audit: auditd enabled with policy
- Sudo: hardened, pty-required, logged

## References

- [cloud-init Autoinstall](https://canonical-subiquity.readthedocs.io/en/latest/user/autoinstall.html)
- [Ubuntu Server 22.04 LTS](https://ubuntu.com/server/docs)
- [systemd Units](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)

## License

Same as parent project (E:\migration)

---

**Status**: ✓ Ready for testing
**Last Updated**: 2026-04-27
