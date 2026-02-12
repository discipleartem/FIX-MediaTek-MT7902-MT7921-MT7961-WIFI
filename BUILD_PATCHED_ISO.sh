#!/bin/bash

# Создание кастомного образа Ubuntu с патчем MT7921

set -e

echo "🔧 Создание кастомного образа Ubuntu с патчем WiFi"

# 1. Проверка прав
if [ "$EUID" -ne 0 ]; then
    echo "Нужны права root. Выполните: sudo ./BUILD_PATCHED_ISO.sh"
    exit 1
fi

# 2. Установка инструментов
echo "1. Установка инструментов..."
apt update
apt install -y squashfs-tools genisoimage syslinux-utils xorriso

# 3. Создание папок
echo "2. Подготовка окружения..."
rm -rf ubuntu-custom ubuntu-patched
mkdir -p ubuntu-custom ubuntu-patched

# 4. Скачивание образа
if [ ! -f "ubuntu-22.04.3-desktop-amd64.iso" ]; then
    echo "3. Скачивание образа Ubuntu..."
    wget -c https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso
fi

# 5. Монтирование образа
echo "4. Монтирование образа..."
mount -o loop ubuntu-22.04.3-desktop-amd64.iso ubuntu-custom

# 6. Копирование файлов
echo "5. Копирование файлов..."
cp -r ubuntu-custom/* ubuntu-patched/
cp -r ubuntu-custom/.disk ubuntu-patched/

# 7. Распаковка filesystem
echo "6. Распаковка filesystem..."
unsquashfs ubuntu-custom/casper/filesystem.squashfs
mv squashfs-root ubuntu-patched/filesystem

# 8. Подготовка chroot
echo "7. Подготовка chroot..."
cp /etc/resolv.conf ubuntu-patched/filesystem/etc/
mount --bind /dev ubuntu-patched/filesystem/dev
mount --bind /proc ubuntu-patched/filesystem/proc
mount --bind /sys ubuntu-patched/filesystem/sys

# 9. Установка патча в chroot
echo "8. Установка патча в chroot..."
chroot ubuntu-patched/filesystem /bin/bash << 'CHROOT_EOF'

# Обновление пакетов
apt update
apt install -y build-essential linux-headers-generic

# Поиск и патч файла pci.c
echo "Поиск файла pci.c..."
PCI_FILE=$(find /usr/src -name "pci.c" -path "*/mt7921/*" 2>/dev/null | head -1)

if [ -n "$PCI_FILE" ]; then
    echo "✅ Найден файл: $PCI_FILE"
    
    # Резервная копия
    cp "$PCI_FILE" "$PCI_FILE.backup"
    
    # Проверяем есть ли уже PCI ID 7902
    if grep -q "0x7902" "$PCI_FILE"; then
        echo "PCI ID 7902 уже есть в файле"
    else
        # Добавляем PCI ID 7902
        sed -i '/{ PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7922),/a\
	{ PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7902),\
		.driver_data = (kernel_ulong_t)MT7921_FIRMWARE_WM },' "$PCI_FILE"
        
        echo "✅ Патч применен!"
        
        # Проверка патча
        echo "Проверка патча:"
        grep -A2 -B2 "0x7902" "$PCI_FILE"
        
        # Сборка модуля
        echo "Сборка модуля..."
        cd /usr/src/linux-headers-$(uname -r)/
        make M=drivers/net/wireless/mediatek/mt76/mt7921 modules
        
        # Установка модуля
        echo "Установка модуля..."
        make M=drivers/net/wireless/mediatek/mt76/mt7921 modules_install
        depmod -a
        
        echo "✅ Модуль собран и установлен!"
    fi
else
    echo "❌ Файл pci.c не найден"
    echo "Доступные файлы mt7921:"
    find /usr/src -name "*" -path "*/mt7921/*" 2>/dev/null | head -5
fi

# Очистка
apt clean
rm -rf /tmp/*

CHROOT_EOF

# 10. Очистка chroot
echo "9. Очистка chroot..."
umount ubuntu-patched/filesystem/dev
umount ubuntu-patched/filesystem/proc
umount ubuntu-patched/filesystem/sys
rm ubuntu-patched/filesystem/etc/resolv.conf

# 11. Создание нового squashfs
echo "10. Создание нового squashfs..."
rm ubuntu-patched/casper/filesystem.squashfs
mksquashfs ubuntu-patched/filesystem ubuntu-patched/casper/filesystem.squashfs

# 12. Обновление размеров
echo "11. Обновление размеров..."
chmod +w ubuntu-patched/casper/filesystem.size
printf $(sudo du -sx --block-size=1 ubuntu-patched/filesystem | cut -f1) > ubuntu-patched/casper/filesystem.size

# 13. Создание нового ISO
echo "12. Создание нового ISO..."
cd ubuntu-patched
mkisofs -r -V "Ubuntu 22.04.3 with MT7921 WiFi Patch" \
    -cache-inodes -J -l \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 \
    -boot-info-table \
    -o ../ubuntu-22.04.3-mt7921-patched.iso .

cd ..

# 14. Очистка
echo "13. Очистка..."
umount ubuntu-custom
rm -rf ubuntu-custom ubuntu-patched

echo "✅ Кастомный образ создан: ubuntu-22.04.3-mt7921-patched.iso"
echo "🎯 Теперь запишите этот образ на флешку и установите Ubuntu с рабочим WiFi!"
