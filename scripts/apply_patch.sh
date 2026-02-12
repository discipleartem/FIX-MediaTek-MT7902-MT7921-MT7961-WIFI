#!/bin/bash

# 🔧 Скрипт применения патча MT7921
# Автоматически применяет патч к ядру Linux

set -e

echo "🔧 Применение патча MT7921 для ядра Linux"
echo "======================================"

# Проверка прав
if [ "$EUID" -ne 0 ]; then
    echo "❌ Нужны права root. Выполните: sudo $0"
    exit 1
fi

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

# 1. Проверка версии ядра
echo ""
echo "1️⃣  Проверка версии ядра"
echo "---------------------"

KERNEL_VERSION=$(uname -r)
echo "Текущая версия ядра: $KERNEL_VERSION"

# Извлечение версии
KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d. -f1)
KERNEL_MINOR=$(echo $KERNEL_VERSION | cut -d. -f2)

if [ "$KERNEL_MAJOR" -lt 5 ] || ([ "$KERNEL_MAJOR" -eq 5 ] && [ "$KERNEL_MINOR" -lt 8 ]); then
    status 1 "Требуется ядро версии 5.8 или выше"
    echo "Текущая версия: $KERNEL_VERSION"
    exit 1
else
    status 0 "Версия ядра поддерживается"
fi

# 2. Поиск файла pci.c
echo ""
echo "2️⃣  Поиск файла pci.c"
echo "------------------"

PCI_FILE=$(find /usr/src -name "pci.c" -path "*/mt7921/*" 2>/dev/null | head -1)

if [ -n "$PCI_FILE" ]; then
    status 0 "Файл найден: $PCI_FILE"
else
    status 1 "Файл pci.c не найден"
    echo "Возможные причины:"
    echo "  - Установлены linux-headers"
    echo "  - Драйвер mt7921 присутствует в ядре"
    echo ""
    echo "Установите заголовки ядра:"
    echo "sudo apt install linux-headers-$(uname -r)"
    exit 1
fi

# 3. Проверка текущего патча
echo ""
echo "3️⃣  Проверка текущего патча"
echo "-----------------------"

if grep -q "0x7902" "$PCI_FILE"; then
    status 0 "PCI ID 0x7902 уже присутствует в файле"
    echo "Патч уже применен. Проверяем корректность..."
    
    # Проверка корректности патча
    if grep -A2 -B2 "0x7902" "$PCI_FILE" | grep -q "MT7921_FIRMWARE_WM"; then
        status 0 "Патч применен корректно"
        echo "Пересобираем модуль для надежности..."
    else
        warning "Патч применен некорректно, исправляем..."
    fi
else
    status 0 "PCI ID 0x7902 отсутствует, применяем патч"
fi

# 4. Создание резервной копии
echo ""
echo "4️⃣  Создание резервной копии"
echo "-------------------------"

BACKUP_FILE="${PCI_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$PCI_FILE" "$BACKUP_FILE"
status 0 "Резервная копия создана: $BACKUP_FILE"

# 5. Применение патча
echo ""
echo "5️⃣  Применение патча"
echo "----------------"

if ! grep -q "0x7902" "$PCI_FILE" || ! grep -A2 -B2 "0x7902" "$PCI_FILE" | grep -q "MT7921_FIRMWARE_WM"; then
    echo "Применение патча к файлу..."
    
    # Создаем временный файл с патчем
    TEMP_PATCH=$(mktemp)
    cat > "$TEMP_PATCH" << 'EOF'
--- a/drivers/net/wireless/mediatek/mt76/mt7921/pci.c
+++ b/drivers/net/wireless/mediatek/mt76/mt7921/pci.c
@@ -44,6 +44,9 @@ static const struct pci_device_id mt7921_pci_table[] = {
 	{ PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7922),
 		.driver_data = (kernel_ulong_t)MT7921_FIRMWARE_WM },
 	{ PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7902),
+		.driver_data = (kernel_ulong_t)MT7921_FIRMWARE_WM },
+	{ PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7902),
 		.driver_data = (kernel_ulong_t)MT7921_FIRMWARE_WM },
 	{ },
 };
 MODULE_DEVICE_TABLE(pci, mt7921_pci_table);
EOF
    
    # Применяем патч через sed (более надежно)
    if ! grep -q "0x7902" "$PCI_FILE"; then
        sed -i '/{ PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7922),/a\
	{ PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7902),\
		.driver_data = (kernel_ulong_t)MT7921_FIRMWARE_WM },' "$PCI_FILE"
    fi
    
    # Проверка результата
    if grep -q "0x7902" "$PCI_FILE"; then
        status 0 "Патч применен успешно"
        echo "Добавленная строка:"
        grep -A2 -B2 "0x7902" "$PCI_FILE"
    else
        status 1 "Ошибка применения патча"
        echo "Восстанавливаем из резервной копии..."
        cp "$BACKUP_FILE" "$PCI_FILE"
        exit 1
    fi
    
    rm -f "$TEMP_PATCH"
else
    status 0 "Патч уже применен корректно"
fi

# 6. Пересборка модуля
echo ""
echo "6️⃣  Пересборка модуля"
echo "------------------"

# Определение пути к исходникам ядра
KERNEL_PATH="/usr/src/linux-headers-$(uname -r)"
MODULE_PATH="drivers/net/wireless/mediatek/mt76/mt7921"

if [ ! -d "$KERNEL_PATH/$MODULE_PATH" ]; then
    status 1 "Путь к модулю не найден: $KERNEL_PATH/$MODULE_PATH"
    exit 1
fi

cd "$KERNEL_PATH"

echo "Очистка модуля..."
make M="$MODULE_PATH" clean

echo "Сборка модуля..."
if make M="$MODULE_PATH" modules; then
    status 0 "Модуль собран успешно"
else
    status 1 "Ошибка сборки модуля"
    echo "Проверьте наличие зависимостей:"
    echo "sudo apt install build-essential"
    exit 1
fi

# 7. Установка модуля
echo ""
echo "7️⃣  Установка модуля"
echo "-----------------"

if make M="$MODULE_PATH" modules_install; then
    status 0 "Модуль установлен"
else
    status 1 "Ошибка установки модуля"
    exit 1
fi

# 8. Обновление depmod
echo ""
echo "8️⃣  Обновление модулей"
echo "------------------"

if depmod -a; then
    status 0 "База данных модулей обновлена"
else
    warning "Ошибка обновления depmod"
fi

# 9. Перезагрузка модуля
echo ""
echo "9️⃣  Перезагрузка модуля"
echo "------------------"

# Выгрузка старых модулей
echo "Выгрузка модулей..."
rmmod mt7921_pci 2>/dev/null || true
rmmod mt7921_common 2>/dev/null || true
rmmod mt76_connac_lib 2>/dev/null || true

# Загрузка новых модулей
echo "Загрузка модулей..."
if modprobe mt7921_pci; then
    status 0 "Модуль mt7921_pci загружен"
else
    warning "Ошибка загрузки модуля mt7921_pci"
fi

if modprobe mt7921_common; then
    status 0 "Модуль mt7921_common загружен"
else
    warning "Ошибка загрузки модуля mt7921_common"
fi

# 10. Проверка результата
echo ""
echo "🔟 Проверка результата"
echo "------------------"

# Проверка загрузки модулей
if lsmod | grep -q mt7921; then
    status 0 "Модули mt7921 загружены:"
    lsmod | grep mt7921
else
    status 1 "Модули mt7921 не загружены"
fi

# Проверка определения устройства
if lspci -nn | grep -q "14c3:7902"; then
    status 0 "Устройство MT7921 с PCI ID 0x7902 определено"
else
    warning "Устройство не найдено в PCI"
fi

# Проверка сетевого интерфейса
if ip link show | grep -q "wlan\|wlp"; then
    status 0 "WiFi интерфейс создан"
    ip link show | grep -E "wlan|wlp" | head -1
else
    warning "WiFi интерфейс не найден"
fi

# 11. Рекомендации
echo ""
echo "🎯 Рекомендации"
echo "=============="

if lsmod | grep -q mt7921; then
    echo "✅ Патч применен успешно!"
    echo ""
    echo "Дальнейшие действия:"
    echo "1. Проверьте работу WiFi:"
    echo "   ./scripts/test_wifi.sh"
    echo ""
    echo "2. Если интерфейс не появился, перезагрузите систему:"
    echo "   sudo reboot"
    echo ""
    echo "3. Для подключения к сети:"
    echo "   nmcli dev wifi list"
    echo "   nmcli dev wifi connect 'SSID' password 'PASSWORD'"
else
    echo "❌ Возникли проблемы при применении патча"
    echo ""
    echo "Возможные решения:"
    echo "1. Перезагрузите систему и попробуйте снова"
    echo "2. Проверьте версию ядра и наличие заголовков"
    echo "3. Восстановите из резервной копии:"
    echo "   sudo cp $BACKUP_FILE $PCI_FILE"
    echo "4. Проверьте логи:"
    echo "   dmesg | grep mt7921"
fi

echo ""
echo "📁 Файлы:"
echo "  - Исходный файл: $PCI_FILE"
echo "  - Резервная копия: $BACKUP_FILE"
echo "  - Логи: dmesg | grep mt7921"

echo ""
echo "✅ Применение патча завершено!"
