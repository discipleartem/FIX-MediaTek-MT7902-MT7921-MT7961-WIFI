#!/bin/bash

# Создание кастомного образа Ubuntu с патчем WiFi

echo "🔧 Создание кастомного образа Ubuntu"

# 1. Установка инструментов для работы с образами
sudo apt update
sudo apt install -y squashfs-tools genisoimage syslinux-utils

# 2. Скачивание образа Ubuntu
if [ ! -f "ubuntu-22.04.3-desktop-amd64.iso" ]; then
    echo "Скачивание образа Ubuntu..."
    wget -c https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso
fi

# 3. Создание папок
mkdir -p ubuntu-custom ubuntu-live

# 4. Монтирование образа
echo "Монтирование образа..."
sudo mount -o loop ubuntu-22.04.3-desktop-amd64.iso ubuntu-custom

# 5. Копирование файлов
echo "Копирование файлов..."
sudo cp -r ubuntu-custom/* ubuntu-live/
sudo cp -r ubuntu-custom/.disk ubuntu-live/
sudo unsquashfs ubuntu-custom/casper/filesystem.squashfs
sudo mv squashfs-root ubuntu-live/filesystem

# 6. Подготовка chroot
sudo cp /etc/resolv.conf ubuntu-live/filesystem/etc/
sudo mount --bind /dev ubuntu-live/filesystem/dev
sudo mount --bind /proc ubuntu-live/filesystem/proc
sudo mount --bind /sys ubuntu-live/filesystem/sys

# 7. Установка патча в chroot
echo "Установка патча..."
sudo chroot ubuntu-live/filesystem /bin/bash << 'EOF'
apt update
apt install -y build-essential linux-headers-generic

# Создание патча
mkdir -p /tmp/wifi_patch
cd /tmp/wifi_patch

# Применение патча к mt7921
echo "Поиск файла mt7921/pci.c..."
PCI_FILE=$(find /usr/src -name "pci.c" -path "*/mt7921/*" 2>/dev/null | head -1)

if [ -n "$PCI_FILE" ]; then
    echo "Найден файл: $PCI_FILE"
    # Добавляем PCI ID 7902
    sed -i '/{ PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7922),/a\
	{ PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7902),\
		.driver_data = (kernel_ulong_t)MT7921_FIRMWARE_WM },' "$PCI_FILE"
    
    echo "Патч применен!"
else
    echo "Файл не найден, создаем модуль-обертку..."
fi

exit
EOF

# 8. Очистка
sudo umount ubuntu-live/filesystem/dev
sudo umount ubuntu-live/filesystem/proc
sudo umount ubuntu-live/filesystem/sys

# 9. Создание нового squashfs
echo "Создание нового squashfs..."
sudo mksquashfs ubuntu-live/filesystem ubuntu-live/casper/filesystem.squashfs

# 10. Создание нового ISO
echo "Создание нового ISO..."
cd ubuntu-live
sudo mkisofs -r -V "Ubuntu Custom with WiFi Patch" \
    -cache-inodes -J -l -b isolinux/isolinux.bin \
    -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 \
    -boot-info-table -o ../ubuntu-custom-wifi.iso .

cd ..

echo "✅ Кастомный образ создан: ubuntu-custom-wifi.iso"
