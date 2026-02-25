# MediaTek MT7902 WiFi - Complete Guide

## 🎯 Overview

Solution for MediaTek MT7902 WiFi adapter (PCI ID: 14c3:7902) on Linux. Includes driver, system optimizations, and fixes for shutdown hanging issues.

## 🚀 Quick Start

```bash
# Full installation
sudo ./mt7902.sh install

# Reboot
sudo reboot

# Check WiFi
lsmod | grep mt7902
nmcli dev status | grep wlan0
```

## 📡 Device and Driver

### Specifications
- **Device:** MediaTek MT7902 WiFi adapter
- **PCI ID:** 14c3:7902
- **Driver:** mt7902 (gen4-mt7902 community driver)
- **Interface:** wlan0

### Driver Check
```bash
# Check if module is loaded
lsmod | grep mt7902

# Check PCI device
lspci | grep -i "mediatek\|7902"

# Check interface
ip addr show wlan0

# Check WiFi status
nmcli dev status | grep wlan0
```

### Problems and Solutions

#### 1. Driver not loading
```bash
# Reload driver
sudo modprobe -r mt7902
sudo modprobe mt7902

# Restart NetworkManager
sudo systemctl restart NetworkManager
```

#### 2. Low WiFi speed
```bash
# Set correct region
sudo iw reg set US

# Check supported frequencies
iw dev wlan0 info | grep freq
```

## ⚙️ System Optimizations

### Problem: System hangs on shutdown

System was hanging during shutdown due to:
- Infinite Docker timeouts (`TimeoutStopUSec=infinity`)
- Issues with mt7902 WiFi driver unloading
- Long NetworkManager timeouts

### Solution: Timeout optimization

#### System timeouts (30 seconds)
```bash
# /etc/systemd/system.conf.d/99-timeouts.conf
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=30s
DefaultTimeoutAbortSec=10s
ShutdownWatchdogSec=1min
```

#### Docker optimization (30 seconds)
```bash
# /etc/systemd/system/docker.service.d/override.conf
[Service]
TimeoutStartSec=60s
TimeoutStopSec=30s
KillMode=mixed
KillSignal=SIGINT
SendSIGKILL=yes
```

#### NetworkManager optimization (15 seconds)
```bash
# /etc/systemd/system/NetworkManager.service.d/override.conf
[Service]
TimeoutStartSec=30s
TimeoutStopSec=15s
KillMode=mixed
SendSIGKILL=yes
```

### Services for proper shutdown

#### Docker shutdown service
```bash
# /etc/systemd/system/docker-shutdown.service
[Unit]
Description=Stop Docker containers before shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/usr/bin/docker stop $(docker ps -q)
ExecStart=/usr/bin/docker kill $(docker ps -q)
TimeoutStartSec=30s
RemainAfterExit=yes

[Install]
WantedBy=halt.target reboot.target shutdown.target
```

#### WiFi driver service
```bash
# /etc/systemd/system/mt7902-driver-shutdown.service
[Unit]
Description=Unload mt7902 driver before shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target
After=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/sbin/modprobe -r mt7902
TimeoutStartSec=10s
RemainAfterExit=yes

[Install]
WantedBy=halt.target reboot.target shutdown.target
```

## 🛠️ Installation and Usage

### Universal Script

The project now uses a single universal script `mt7902.sh` for all operations:

```bash
# Full installation (driver + system settings)
sudo ./mt7902.sh install

# Driver only
sudo ./mt7902.sh driver

# System settings only
sudo ./mt7902.sh system

# Verify installation
./mt7902.sh verify

# Remove installation
sudo ./mt7902.sh remove

# Prepare patches for kernel submission
./mt7902.sh patch

# Check patch format
./mt7902.sh patch-check

# System status
./mt7902.sh status

# Full diagnostics
./mt7902.sh diagnose

# Help
./mt7902.sh help
```

### Makefile Commands

```bash
# Quick installation
make quick-install

# Full installation
sudo make install

# Prepare patches
make patch

# Check patches
make patch-check

# Check status
make check-status

# Test
make test

# Diagnose
make diagnose

# Clean
make clean

# Remove
sudo make uninstall

# Help
make help
```

## 🔍 Diagnostics

### System Check
```bash
# Driver status
lsmod | grep mt7902

# Device
lspci | grep -i "mediatek\|7902"

# Interface
ip addr show wlan0

# Services
systemctl status mt7902-driver-shutdown.service
systemctl status docker-shutdown.service

# Timeouts
systemctl show docker --property=TimeoutStopUSec
systemctl show NetworkManager --property=TimeoutStopUSec
```

### Script Diagnostics
```bash
# Check installation
./mt7902.sh verify

# Full diagnostics
./mt7902.sh diagnose

# Check status
./mt7902.sh status

# Check patches
./mt7902.sh patch-check
```

### Troubleshooting

#### WiFi not working
```bash
# 1. Check driver
lsmod | grep mt7902

# 2. Reload driver
sudo modprobe -r mt7902 && sudo modprobe mt7902

# 3. Restart NetworkManager
sudo systemctl restart NetworkManager

# 4. Check device
lspci | grep -i "mediatek\|7902"
```

#### System hangs on shutdown
```bash
# 1. Check services
systemctl status mt7902-driver-shutdown.service
systemctl status docker-shutdown.service

# 2. Check timeouts
systemctl show --property=DefaultTimeoutStopUSec

# 3. Check configuration
cat /etc/systemd/system.conf.d/99-timeouts.conf
```

#### Docker containers stop slowly
```bash
# 1. Check Docker timeouts
systemctl show docker --property=TimeoutStopUSec

# 2. Check service
systemctl status docker-shutdown.service

# 3. Manual stop
sudo docker stop $(docker ps -q)
```

## 📋 Requirements

### System
- **OS:** Ubuntu/Debian (recommended), CentOS/RHEL, Fedora
- **Kernel:** Linux 5.4+ (mt7902 support)
- **Packages:** build-essential, linux-headers, git, dkms

### Software
- **systemd** for service management
- **NetworkManager** for network management
- **Docker** optional, for container optimization

## 🎯 Results

### After installation
- **📡 WiFi works** - MediaTek MT7902 fully functional
- **⚡ Fast shutdown** - 15-30 seconds instead of hanging
- **🐳 Docker stops quickly** - 30 seconds timeout
- **🌐 Network stable** - NetworkManager optimized
- **🔄 Autoload** - driver loads on system start

### Comparison
| Parameter | Before | After |
|-----------|---------|--------|
| WiFi | ❌ Not working | ✅ Fully functional |
| Shutdown | ❌ Hanging | ✅ 15-30 seconds |
| Docker | ❌ Infinite timeout | ✅ 30 seconds |
| NetworkManager | ❌ Long stop | ✅ 15 seconds |
| Autoload | ❌ Missing | ✅ Configured |

## 🔄 Maintenance

### Driver Update
```bash
# Rebuild and install
make clean
make gen4-driver
sudo make install-gen4
```

### Reset Settings
```bash
# Remove and reinstall
sudo ./mt7902.sh remove
sudo ./mt7902.sh install
```

### Version Check
```bash
# Kernel version
uname -r

# Driver version
modinfo mt7902 | grep version

# Project version
git log -1 --oneline
```

## 📞 Support

### Quick Help
```bash
# Diagnose problems
./mt7902.sh diagnose

# Check status
./mt7902.sh status

# Help
./mt7902.sh help
make help
```

### Bug Reports
- **GitHub Issues:** Report a problem
- **Diagnostics:** Use `make diagnose` to collect information

### Useful Commands
```bash
# Check WiFi
nmcli dev wifi list

# Error logs
journalctl -b -p err | tail -10

# Driver logs
journalctl -b | grep -i "mt7902\|mediatek"

# Service status
systemctl list-units --type=service --state=failed
```

## 📄 Project Structure

```
FIX-MediaTek-MT7902-MT7921-MT7961-WIFI/
├── 🚀 mt7902.sh                    # Universal script (install + patches)
├── 🔨 Makefile                       # Main commands
├── 📦 gen4-mt7902/                   # Community driver
├── 🩹 patches/                       # Kernel patches
├── � GUIDE_EN.md                    # This file (English)
├── 📚 GUIDE_RU.md                    # Russian guide
├── 📋 README.md                      # Short description
└── 📄 LICENSE                        # License
```

## 🎉 Ready to Use!

Run `sudo ./mt7902.sh install` for complete driver and system optimization installation.

**Key commands:**
- `sudo ./mt7902.sh install` - full installation
- `./mt7902.sh patch` - prepare patches
- `./mt7902.sh diagnose` - problem diagnostics
- `./mt7902.sh help` - help
