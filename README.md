# MediaTek MT7921/MT7902/MT7961 WiFi Driver Fix for Linux

> 🚀 **Complete solution** for MediaTek Gen4 WiFi adapters not recognized by Linux kernel

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-orange.svg)]()
[![Driver](https://img.shields.io/badge/Driver-MT7921%20%2F%20MT7902%20%2F%20MT7961-green.svg)]()

## � Table of Contents

- [Problem Description](#-problem-description)
- [Supported Devices](#-supported-devices)
- [Installation Guide](#-installation-guide)
- [Verification](#-verification)
- [Features](#-features)
- [Troubleshooting](#-troubleshooting)
- [Project Structure](#-project-structure)

## 🚨 Problem Description

MediaTek MT7921 WiFi adapter (PCI ID: `14c3:7902`) is not recognized by Linux kernel and shows as **"UNCLAIMED"** device in `lspci` output.

### Symptoms
- WiFi device not appearing in network managers
- `lspci -nn` shows device as unclaimed
- No wireless interface available (`iwconfig` shows no wlan devices)

## Solution

Use the **gen4-mt7902** driver - a community-developed driver based on MediaTek's source code that provides full WiFi functionality.

Original Repository: https://github.com/hmtheboy154/gen4-mt7902

## Supported Devices

| Device | PCI ID | Status |
|--------|--------|--------|
| **MT7902** | `14c3:7902` | Fully Supported |
| **MT7921** variants | Various | Compatible |
| **MT7961** | Various | Compatible |
| Other MediaTek Gen4 WiFi chips | Various | May Work |
| **MT7961** | Various | ✅ Compatible |
| Other MediaTek Gen4 WiFi chips | Various | ⚠️ May Work |

## 🛠️ Installation Guide

### Prerequisites

Install required build tools and kernel headers:

```bash
sudo apt update
sudo apt install build-essential dkms linux-headers-$(uname -r) git
```

### Step 1: Clone the Driver Repository

```bash
git clone https://github.com/hmtheboy154/gen4-mt7902
cd gen4-mt7902
```

### Step 2: Build and Install Driver

```bash
# Build using all CPU cores
make -j$(nproc)

# Install the driver
sudo make install -j$(nproc)
```

### Step 3: Install Firmware

```bash
sudo make install_fw
```

### Step 4: Load the Driver

```bash
sudo modprobe mt7902
```

### Step 5: Enable Auto-loading (Recommended)

```bash
echo "mt7902" | sudo tee -a /etc/modules-load.d/mt7902.conf
```

### Step 6: Reboot System

```bash
sudo reboot
```

## ✅ Verification

After reboot, verify WiFi functionality:

```bash
# Check device status
nmcli device status

# Expected output:
# DEVICE  TYPE      STATE      CONNECTION
# wlan0   wifi      connected  YourNetwork

# Scan for available networks
nmcli device wifi list

# Should show available WiFi networks in your area
```

Alternative verification methods:

```bash
# Check if driver is loaded
lsmod | grep mt7902

# Check device recognition
lspci -nn | grep 14c3:7902

# Verify wireless interface
iwconfig
```

## 🌟 Features

| Feature | Status |
|---------|--------|
| 📶 **Full WiFi connectivity** (2.4GHz & 5GHz) | ✅ Working |
| 🔗 **NetworkManager integration** | ✅ Working |
| 🔒 **WPA/WPA2/WPA3 support** | ✅ Working |
| 🔍 **WiFi scanning and connection** | ✅ Working |
| 📱 **P2P support** | ✅ Working |
| 🚀 **Auto-loading on boot** | ✅ Working |

## ⚠️ Known Issues

| Issue | Workaround |
|-------|------------|
| WPA3 may have issues with iwd | Use `wpa_supplicant` instead |
| WiFi hotspot functionality may be limited | Use alternative hotspot solutions |
| Suspend/resume may require driver reload | `sudo modprobe -r mt7902 && sudo modprobe mt7902` |

## 🔧 Troubleshooting

### WiFi Not Detected

```bash
# Check if driver is loaded
lsmod | grep mt7902

# Check device recognition
lspci -nn | grep 14c3:7902

# Reload driver
sudo rmmod mt7902
sudo modprobe mt7902
```

### NetworkManager Doesn't See WiFi

```bash
# Restart NetworkManager service
sudo systemctl restart NetworkManager

# Check device type and status
nmcli device status

# Check system logs for errors
dmesg | grep -i mt79
journalctl -xe | grep -i network
```

### Driver Fails to Load

```bash
# Check kernel logs
dmesg | grep mt7902

# Verify firmware installation
ls -la /lib/firmware/mediatek/

# Reinstall firmware if needed
cd gen4-mt7902 && sudo make install_fw
```

## 📁 Project Structure

```
FIX-MediaTek-MT7902-MT7921-MT7961-WIFI/
├── gen4-mt7902/                    # ✅ Working community driver
├── mt7921e_simple_patch.c           # 🚧 Custom driver patch (WIP)
├── mt7921e_simple_patch.ko          # 📦 Compiled driver module
├── Makefile                         # 🔨 Build configuration
├── MT7921_WIFI_FIX_EN.md           # 📖 English instructions
├── MT7921_WIFI_FIX_RU.md           # 📖 Russian instructions
├── LICENSE                         # 📄 License file
└── README.md                       # 📋 This file
```

## � Additional Resources

- **Driver Source**: https://github.com/hmtheboy154/gen4-mt7902
- **Community Support**: GitHub issues and discussions
- **Documentation**: `MT7921_WIFI_FIX_EN.md` and `MT7921_WIFI_FIX_RU.md`

## 📄 License

This driver follows MediaTek's licensing terms and is provided as-is for community use.

---

> **💡 Tip**: If you encounter any issues, please check the troubleshooting section above or visit the driver's GitHub repository for community support.
