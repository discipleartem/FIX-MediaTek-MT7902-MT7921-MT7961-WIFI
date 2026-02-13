# MediaTek MT7921 PCI ID 7902 Linux Driver

## 🎯 Objective
Add support for MediaTek MT7921 WiFi adapter with PCI ID 14c3:7902 to the Linux kernel.

## � What's Included

### ✅ Kernel Patch
- **File:** `patches/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch`
- **Purpose:** Add PCI ID 7902 support to MT7921 driver
- **Format:** Properly formatted for Linux kernel submission
- **Status:** Ready for submission to linux-wireless@vger.kernel.org

### 📊 Patch Details
```c
{ PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7902),
    .driver_data = (kernel_ulong_t)MT7921_FIRMWARE_WM },
```

This adds support for device `14c3:7902` with the same configuration as the existing `14c3:7922` variant.

## � Usage

### For Kernel Developers
```bash
# Submit patch to Linux kernel
git send-email \
  --to="nbd@nbd.name, lorenzo@kernel.org" \
  --cc="linux-wireless@vger.kernel.org" \
  --cc="mediatek@lists.infradead.org" \
  --subject-prefix="PATCH net-next" \
  patches/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch
```

### For End Users
After patch acceptance in upstream kernel:
1. Update to kernel version that includes the patch
2. The MT7921 device with PCI ID 7902 will work automatically
3. No additional driver installation required

## 📧 Hardware Support

### ✅ Supported Device
- **Device:** MediaTek MT7921 WiFi Adapter
- **PCI ID:** 14c3:7902
- **Configuration:** MT7921_FIRMWARE_WM
- **Status:** Patch ready for upstream submission

### 🏷️ Commonly Found In
- Acer Aspire 3 laptops
- Other budget notebooks with MediaTek WiFi

## � Testing Results

### ✅ Verified On
- **Hardware:** Acer Aspire 3 with MT7921 (14c3:7902)
- **Kernel:** Linux 6.8.0 (Ubuntu 24.04.4)
- **Functionality:** WiFi connection, network scanning, data transfer
- **Status:** Working correctly with existing MT7921_FIRMWARE_WM config

## 📋 Kernel Submission

### 🎯 Maintainers
- **Felix Fietkau** <nbd@nbd.name>
- **Lorenzo Bianconi** <lorenzo@kernel.org>

### � Mailing Lists
- **Primary:** linux-wireless@vger.kernel.org
- **Secondary:** mediatek@lists.infradead.org
- **Network:** netdev@vger.kernel.org

### 📝 Submission Process
1. **Check formatting:** `./scripts/checkpatch.pl patches/0001-*.patch`
2. **Get maintainers:** `./scripts/get_maintainer.pl patches/0001-*.patch`
3. **Send patch:** `git send-email` with proper recipients
4. **Monitor:** patchwork.kernel.org for review status

## 📄 License
MIT License - see [LICENSE](LICENSE) file for details.

## � Links

- **Linux Kernel:** https://www.kernel.org/
- **Patchwork:** https://patchwork.kernel.org/project/linux-wireless/
- **Mailing Lists:** https://lore.kernel.org/linux-wireless/
- **Submission Guide:** https://www.kernel.org/doc/html/latest/process/submitting-patches.html

## � Contributing

### 🎯 How to Contribute
1. **Test** the patch thoroughly
2. **Review** the patch for coding standards
3. **Submit** improvements via pull requests
4. **Discuss** changes in kernel mailing lists

### 📋 Development
- **Branch:** master
- **Format:** Linux kernel patch format
- **Documentation:** Inline with patch
- **Testing:** Required before submission

---

**Adding WiFi support for MediaTek MT7921 devices to the Linux kernel!** 🚀
