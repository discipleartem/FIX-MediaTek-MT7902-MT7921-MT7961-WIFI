# MT7921 WiFi Adapter Fix for Linux

## Problem
MediaTek MT7921 WiFi adapter (PCI ID: 14c3:7902) is not recognized by Linux kernel and shows as "UNCLAIMED" device.

## Solution
Use the gen4-mt7902 driver - a community-developed driver based on MediaTek's source code that provides full WiFi functionality.

## Supported Devices
- **MT7902** (PCI ID: 14c3:7902) - Main target
- **MT7921** variants with similar hardware
- **MT7961** compatible devices  
- Other MediaTek Gen4 WiFi chips

## Installation Instructions

### Prerequisites
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
make -j$(nproc)
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

### Step 5: Enable Auto-loading (Optional)
```bash
echo "mt7902" | sudo tee -a /etc/modules-load.d/mt7902.conf
```

### Step 6: Reboot
```bash
sudo reboot
```

## Verification

After reboot, check if WiFi is working:

```bash
# Check device status
nmcli device status

# Should show wlan0 as wifi device
# DEVICE  TYPE      STATE      CONNECTION
# wlan0   wifi      connected  YourNetwork

# Scan for networks
nmcli device wifi list

# Should show available WiFi networks
```

## Features
- ✅ Full WiFi connectivity (2.4GHz & 5GHz)
- ✅ NetworkManager integration
- ✅ WPA/WPA2/WPA3 support
- ✅ WiFi scanning and connection
- ✅ P2P support
- ✅ Auto-loading on boot

## Known Issues
- WPA3 may have issues with iwd (use wpa_supplicant instead)
- WiFi hotspot functionality may be limited
- Suspend/resume may require driver reload

## Troubleshooting

### If WiFi is not detected:
```bash
# Check if driver is loaded
lsmod | grep mt7902

# Check device recognition
lspci -nn | grep 14c3:7902

# Reload driver
sudo rmmod mt7902
sudo modprobe mt7902
```

### If NetworkManager doesn't see WiFi:
```bash
# Restart NetworkManager
sudo systemctl restart NetworkManager

# Check device type
nmcli device status
```

## Driver Source
Based on: https://github.com/hmtheboy154/gen4-mt7902

Community-developed driver with MediaTek's source code modifications for Linux compatibility.

## License
This driver follows MediaTek's licensing terms and is provided as-is for community use.
