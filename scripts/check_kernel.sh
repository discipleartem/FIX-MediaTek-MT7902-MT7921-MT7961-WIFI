#!/bin/bash

# 🔍 Скрипт проверки совместимости ядра
# Проверяет поддерживает ли ядро MT7921

set -e

echo "🔍 Проверка совместимости ядра для MT7921"
echo "======================================"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        return 1
    fi
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo "ℹ️  $1"
}

# 1. Базовая информация о системе
echo ""
echo "1️⃣  Информация о системе"
echo "---------------------"

echo "ОС: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Неизвестная ОС')"
echo "Ядро: $(uname -r)"
echo "Архитектура: $(uname -m)"
echo "Дата сборки: $(uname -v)"

# 2. Анализ версии ядра
echo ""
echo "2️⃣  Анализ версии ядра"
echo "-------------------"

KERNEL_VERSION=$(uname -r)
KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d. -f1)
KERNEL_MINOR=$(echo $KERNEL_VERSION | cut -d. -f2)
KERNEL_PATCH=$(echo $KERNEL_VERSION | cut -d. -f3 | cut -d- -f1)

echo "Версия: $KERNEL_MAJOR.$KERNEL_MINOR.$KERNEL_PATCH"

# Проверка минимальной версии
if [ "$KERNEL_MAJOR" -lt 5 ]; then
    status 1 "Ядро версии < 5.x не поддерживается"
    echo "Требуется ядро 5.8 или выше"
    exit 1
elif [ "$KERNEL_MAJOR" -eq 5 ] && [ "$KERNEL_MINOR" -lt 8 ]; then
    status 1 "Ядро версии 5.$KERNEL_MINOR не поддерживается"
    echo "Требуется ядро 5.8 или выше"
    exit 1
else
    status 0 "Версия ядра поддерживается"
fi

# Рекомендации по версиям
if [ "$KERNEL_MAJOR" -ge 6 ]; then
    status 0 "Ядро 6.x - рекомендуется"
elif [ "$KERNEL_MAJOR" -eq 5 ] && [ "$KERNEL_MINOR" -ge 15 ]; then
    status 0 "Ядро 5.15+ - рекомендуется"
elif [ "$KERNEL_MAJOR" -eq 5 ] && [ "$KERNEL_MINOR" -ge 8 ]; then
    warning "Ядро 5.8-5.14 - поддерживается, но рекомендуется обновить"
fi

# 3. Проверка конфигурации ядра
echo ""
echo "3️⃣  Проверка конфигурации ядра"
echo "---------------------------"

CONFIG_FILE="/boot/config-$(uname -r)"

if [ -f "$CONFIG_FILE" ]; then
    echo "Файл конфигурации найден: $CONFIG_FILE"
    
    # Проверка важных опций
    echo "Проверка конфигурации..."
    
    # CFG80211
    if grep -q "CONFIG_CFG80211=y" "$CONFIG_FILE"; then
        status 0 "CFG80211 включен"
    elif grep -q "CONFIG_CFG80211=m" "$CONFIG_FILE"; then
        status 0 "CFG80211 как модуль"
    else
        status 1 "CFG80211 не включен"
    fi
    
    # MAC80211
    if grep -q "CONFIG_MAC80211=y" "$CONFIG_FILE"; then
        status 0 "MAC80211 включен"
    elif grep -q "CONFIG_MAC80211=m" "$CONFIG_FILE"; then
        status 0 "MAC80211 как модуль"
    else
        status 1 "MAC80211 не включен"
    fi
    
    # PCI поддержка
    if grep -q "CONFIG_PCI=y" "$CONFIG_FILE"; then
        status 0 "PCI поддержка включена"
    else
        status 1 "PCI поддержка не включена"
    fi
    
    # MediaTek драйверы
    if grep -q "CONFIG_MT76_CORE=m" "$CONFIG_FILE" 2>/dev/null; then
        status 0 "MT76 CORE как модуль"
    elif grep -q "CONFIG_MT76_CORE=y" "$CONFIG_FILE" 2>/dev/null; then
        status 0 "MT76 CORE включен"
    else
        warning "MT76 CORE не найден в конфигурации"
    fi
    
    # MT7921
    if grep -q "CONFIG_MT7921=m" "$CONFIG_FILE" 2>/dev/null; then
        status 0 "MT7921 как модуль"
    elif grep -q "CONFIG_MT7921=y" "$CONFIG_FILE" 2>/dev/null; then
        status 0 "MT7921 включен"
    else
        warning "MT7921 не найден в конфигурации"
    fi
    
else
    status 1 "Файл конфигурации не найден"
    echo "Установите заголовки ядра:"
    echo "sudo apt install linux-headers-$(uname -r)"
fi

# 4. Проверка заголовков ядра
echo ""
echo "4️⃣  Проверка заголовков ядра"
echo "------------------------"

HEADERS_PATH="/usr/src/linux-headers-$(uname -r)"

if [ -d "$HEADERS_PATH" ]; then
    status 0 "Заголовки ядра найдены: $HEADERS_PATH"
    
    # Проверка структуры
    if [ -f "$HEADERS_PATH/Makefile" ]; then
        status 0 "Makefile найден"
    else
        warning "Makefile не найден"
    fi
    
    if [ -d "$HEADERS_PATH/drivers" ]; then
        status 0 "Драйверы найдены"
    else
        warning "Директория drivers не найдена"
    fi
    
    if [ -d "$HEADERS_PATH/include" ]; then
        status 0 "Include файлы найдены"
    else
        warning "Директория include не найдена"
    fi
    
else
    status 1 "Заголовки ядра не найдены"
    echo "Установите заголовки:"
    echo "sudo apt install linux-headers-$(uname -r)"
fi

# 5. Проверка исходников mt7921
echo ""
echo "5️⃣  Проверка исходников MT7921"
echo "--------------------------"

PCI_FILE=$(find /usr/src -name "pci.c" -path "*/mt7921/*" 2>/dev/null | head -1)

if [ -n "$PCI_FILE" ]; then
    status 0 "Исходники MT7921 найдены: $PCI_FILE"
    
    # Проверка содержимого
    if grep -q "mt7921_pci_table" "$PCI_FILE"; then
        status 0 "Таблица PCI устройств найдена"
    else
        warning "Таблица PCI устройств не найдена"
    fi
    
    # Проверка текущего патча
    if grep -q "0x7902" "$PCI_FILE"; then
        status 0 "PCI ID 0x7902 уже присутствует"
    else
        warning "PCI ID 0x7902 отсутствует, требуется патч"
    fi
    
else
    status 1 "Исходники MT7921 не найдены"
    echo "Возможные причины:"
    echo "  - Драйвер MT7921 не включен в ядро"
    echo "  - Неполная установка заголовков"
    echo "  - Старая версия ядра"
fi

# 6. Проверка зависимостей
echo ""
echo "6️⃣  Проверка зависимостей"
echo "---------------------"

# Проверка build-essential
if dpkg -l | grep -q "build-essential"; then
    status 0 "build-essential установлен"
else
    warning "build-essential не установлен"
    echo "Установите: sudo apt install build-essential"
fi

# Проверка gcc
if command -v gcc >/dev/null 2>&1; then
    GCC_VERSION=$(gcc --version | head -1)
    status 0 "GCC найден: $GCC_VERSION"
else
    status 1 "GCC не найден"
    echo "Установите: sudo apt install gcc"
fi

# Проверка make
if command -v make >/dev/null 2>&1; then
    MAKE_VERSION=$(make --version | head -1)
    status 0 "Make найден: $MAKE_VERSION"
else
    status 1 "Make не найден"
    echo "Установите: sudo apt install make"
fi

# Проверка wireless-tools
if command -v iw >/dev/null 2>&1; then
    status 0 "iw установлен"
else
    warning "iw не установлен"
    echo "Установите: sudo apt install wireless-tools"
fi

# 7. Проверка firmware
echo ""
echo "7️⃣  Проверка firmware"
echo "------------------"

FIRMWARE_DIR="/lib/firmware/mediatek"

if [ -d "$FIRMWARE_DIR" ]; then
    status 0 "Директория firmware MediaTek найдена"
    
    MT7921_FIRMWARE=$(find "$FIRMWARE_DIR" -name "mt7921*" 2>/dev/null)
    if [ -n "$MT7921_FIRMWARE" ]; then
        status 0 "Firmware MT7921 найдена:"
        echo "$MT7921_FIRMWARE" | head -3
    else
        warning "Firmware MT7921 не найдена"
        echo "Установите: sudo apt install linux-firmware"
    fi
else
    warning "Директория firmware MediaTek не найдена"
    echo "Установите: sudo apt install linux-firmware"
fi

# 8. Проверка текущего состояния
echo ""
echo "8️⃣  Текущее состояние системы"
echo "--------------------------"

# Проверка загруженных модулей
if lsmod | grep -q mt7921; then
    status 0 "Модули MT7921 загружены"
    lsmod | grep mt7921
else
    warning "Модули MT7921 не загружены"
fi

# Проверка PCI устройств
if lspci -nn | grep -q -i mediatek; then
    status 0 "Устройство MediaTek найдено в PCI"
    lspci -nn | grep -i mediatek
else
    warning "Устройство MediaTek не найдено в PCI"
fi

# Проверка WiFi интерфейсов
if ip link show | grep -q "wlan\|wlp"; then
    status 0 "WiFi интерфейсы найдены"
    ip link show | grep -E "wlan|wlp" | head -1
else
    warning "WiFi интерфейсы не найдены"
fi

# 9. Итоговая оценка
echo ""
echo "9️⃣  Итоговая оценка совместимости"
echo "=============================="

# Подсчет успешных проверок
TOTAL_CHECKS=0
PASSED_CHECKS=0

# Счетчик можно реализовать, но для простоты используем логику
echo "Анализ результатов..."

# Базовые требования
KERNEL_OK=false
HEADERS_OK=false
DEPS_OK=false

if [ "$KERNEL_MAJOR" -ge 5 ] && ([ "$KERNEL_MAJOR" -gt 5 ] || [ "$KERNEL_MINOR" -ge 8 ]); then
    KERNEL_OK=true
fi

if [ -d "$HEADERS_PATH" ]; then
    HEADERS_OK=true
fi

if command -v gcc >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
    DEPS_OK=true
fi

if $KERNEL_OK && $HEADERS_OK && $DEPS_OK; then
    status 0 "Система готова к применению патча"
    echo ""
    echo "🎯 Рекомендуемые действия:"
    echo "1. Примените патч:"
    echo "   sudo ./scripts/apply_patch.sh"
    echo ""
    echo "2. Проверьте результат:"
    echo "   ./scripts/test_wifi.sh"
elif $KERNEL_OK && $HEADERS_OK; then
    warning "Система почти готова"
    echo ""
    echo "🔧 Установите недостающие зависимости:"
    echo "sudo apt install build-essential gcc make wireless-tools"
elif $KERNEL_OK; then
    warning "Требуется установка заголовков ядра"
    echo ""
    echo "🔧 Установите заголовки:"
    echo "sudo apt install linux-headers-$(uname -r)"
else
    status 1 "Система не готова"
    echo ""
    echo "🔄 Рекомендуется обновить ядро:"
    echo "sudo apt update && sudo apt install linux-image-generic"
fi

# 10. Дополнительная информация
echo ""
echo "🔟 Дополнительная информация"
echo "========================"

echo "Полная информация о ядре:"
echo "  Версия: $(uname -r)"
echo "  Сборка: $(uname -v)"
echo "  Архитектура: $(uname -m)"
echo "  Процессор: $(uname -p)"

echo ""
echo "Системные дистрибутивы с поддержкой MT7921:"
echo "  ✅ Ubuntu 20.04+ (рекомендуется 22.04+)"
echo "  ✅ Debian 11+"
echo "  ✅ Linux Mint 20+"
echo "  ✅ Fedora 34+"
echo "  ✅ Arch Linux (rolling)"

echo ""
echo "Минимальные системные требования:"
echo "  - Ядро Linux 5.8+"
echo "  - 2GB RAM"
echo "  - 5GB дискового пространства"
echo "  - Поддержка PCI"

echo ""
echo "✅ Проверка завершена!"
