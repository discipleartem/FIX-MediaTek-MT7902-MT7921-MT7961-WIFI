# 🐛 Устранение проблем с MT7921

## 📋 Обзор

Этот документ содержит решения распространенных проблем с WiFi адаптером MediaTek MT7921.

## 🔍 Частые проблемы

### ❌ Проблема: Устройство не определяется

**Симптомы:**
```bash
lspci -nn | grep -i mediatek
# Нет вывода
```

**Решения:**

1. **Проверьте физическое подключение:**
   ```bash
   # Проверьте PCI устройства
   lspci -v | grep -i network
   
   # Проверьте все MediaTek устройства
   lspci -nn | grep 14c3
   ```

2. **Проверьте BIOS/UEFI:**
   - Убедитесь что WiFi включен в BIOS
   - Отключите "Fast Boot"
   - Обновите BIOS до последней версии

3. **Сброс PCI:**
   ```bash
   # Перезагрузите PCI шину
   sudo echo 1 > /sys/bus/pci/devices/0000:*/reset
   ```

### ❌ Проблема: Модуль не загружается

**Симптомы:**
```bash
lsmod | grep mt7921
# Нет вывода
```

**Решения:**

1. **Проверьте версию ядра:**
   ```bash
   uname -r
   # Требуется >= 5.8
   ```

2. **Проверьте наличие модуля:**
   ```bash
   find /lib/modules -name "mt7921*" 2>/dev/null
   ```

3. **Загрузите модуль вручную:**
   ```bash
   sudo modprobe mt7921_pci
   sudo modprobe mt7921_common
   ```

4. **Проверьте зависимости:**
   ```bash
   sudo modprobe cfg80211
   sudo modprobe mac80211
   ```

### ❌ Проблема: Интерфейс wlan0 не создается

**Симптомы:**
```bash
ip link show
# Нет wlan0
```

**Решения:**

1. **Проверьте загрузку firmware:**
   ```bash
   dmesg | grep "mt7921 firmware"
   
   # Если firmware не найдена:
   sudo apt install linux-firmware
   ```

2. **Проверьте права доступа:**
   ```bash
   # Проверьте группы пользователя
   groups $USER
   
   # Добавьте в группу netdev если нужно
   sudo usermod -a -G netdev $USER
   ```

3. **Перезагрузите сетевые сервисы:**
   ```bash
   sudo systemctl restart NetworkManager
   sudo systemctl restart networking
   ```

### ❌ Проблема: WiFi не видит сети

**Симптомы:**
```bash
nmcli dev wifi list
# Пустой список
```

**Решения:**

1. **Проверьте регуляторный домен:**
   ```bash
   sudo iw reg set US
   sudo iw reg get
   ```

2. **Включите WiFi:**
   ```bash
   sudo rfkill unblock wifi
   rfkill list
   ```

3. **Перезагрузите интерфейс:**
   ```bash
   sudo ip link set wlan0 down
   sudo ip link set wlan0 up
   ```

4. **Обновите прошивку:**
   ```bash
   # Скачайте последнюю firmware
   wget https://github.com/openwrt/mt76/raw/master/firmware/mt7921_wa.bin
   wget https://github.com/openwrt/mt76/raw/master/firmware/mt7921_wm.bin
   sudo cp mt7921_*.bin /lib/firmware/mediatek/
   ```

### ❌ Проблема: Подключение к сети не работает

**Симптомы:**
```bash
nmcli dev wifi connect "SSID"
# Ошибка подключения
```

**Решения:**

1. **Проверьте пароль и шифрование:**
   ```bash
   # Попробуйте WPA2
   nmcli dev wifi connect "SSID" password "pass" key-mgmt wpa-psk
   ```

2. **Отключите MAC фильтрацию:**
   - Проверьте настройки роутера
   - Временно отключите MAC фильтрацию

3. **Используйте wpa_supplicant напрямую:**
   ```bash
   # Создайте конфигурацию
   wpa_passphrase "SSID" "password" > wpa.conf
   
   # Подключитесь
   sudo wpa_supplicant -B -i wlan0 -c wpa.conf
   sudo dhclient wlan0
   ```

### ❌ Проблема: Низкая скорость или обрывы

**Симптомы:**
```bash
ping -c 10 8.8.8.8
# Высокий ping или потери пакетов
```

**Решения:**

1. **Измените канал WiFi:**
   ```bash
   # Проверите загруженность каналов
   sudo iw dev wlan0 scan | grep "DS Parameter set"
   
   # Измените канал в настройках роутера на менее загруженный
   ```

2. **Отключите энергосбережение:**
   ```bash
   sudo iw dev wlan0 set power_save off
   ```

3. **Обновите драйвер:**
   ```bash
   # Пересоберите модуль с оптимизациями
   cd /usr/src/linux-headers-$(uname -r)/
   sudo make M=drivers/net/wireless/mediatek/mt76/mt7921 clean
   sudo make M=drivers/net/wireless/mediatek/mt76/mt7921 modules
   sudo make M=drivers/net/wireless/mediatek/mt76/mt7921 modules_install
   ```

## 🔧 Диагностические команды

### Полная диагностика
```bash
#!/bin/bash
echo "=== MT7921 Полная диагностика ==="
echo "Дата: $(date)"
echo "Система: $(uname -a)"
echo ""

echo "=== PCI Устройства ==="
lspci -nnv | grep -A 10 -i mediatek
echo ""

echo "=== USB Устройства ==="
lsusb | grep -i mediatek
echo ""

echo "=== Загруженные модули ==="
lsmod | grep -E "(mt79|cfg80211|mac80211)"
echo ""

echo "=== Firmware ==="
dmesg | grep -i firmware | grep -i mt7921
echo ""

echo "=== Сетевые интерфейсы ==="
ip link show
echo ""

echo "=== Блокировки радиомодулей ==="
rfkill list
echo ""

echo "=== Регуляторный домен ==="
iw reg get
echo ""

echo "=== Логи NetworkManager ==="
journalctl -u NetworkManager | tail -20
echo ""

echo "=== Логи wpa_supplicant ==="
journalctl -u wpa_supplicant | tail -20
echo ""

echo "=== Проблемы в dmesg ==="
dmesg | grep -E "(mt7921|wlan|error|fail)" | tail -20
```

### Мониторинг в реальном времени
```bash
# Мониторинг логов
sudo journalctl -f | grep -E "(mt7921|wlan|NetworkManager)"

# Мониторинг WiFi
watch -n 1 "iw dev wlan0 link"

# Мониторинг сигнала
watch -n 1 "cat /proc/net/wireless"
```

## 📞 Создание отчета о проблеме

При обращении за помощью предоставьте:

1. **Вывод диагностики:**
   ```bash
   ./scripts/full_diagnostic.sh > diagnostic.log
   ```

2. **Описание проблемы:**
   - Когда появилась проблема
   - Что менялось в системе
   - Шаги воспроизведения

3. **Логи:**
   - `/var/log/syslog`
   - `journalctl -b`
   - `dmesg`

## 🔄 Восстановление системы

Если ничего не помогает:

1. **Сброс сетевых настроек:**
   ```bash
   sudo systemctl stop NetworkManager
   sudo rm /etc/NetworkManager/NetworkManager.state
   sudo systemctl start NetworkManager
   ```

2. **Переустановка драйверов:**
   ```bash
   sudo apt remove --purge linux-firmware
   sudo apt install linux-firmware
   sudo reboot
   ```

3. **Откат патча:**
   ```bash
   # Восстановите резервную копию
   sudo cp /usr/src/linux-headers-$(uname -r)/drivers/net/wireless/mediatek/mt76/mt7921/pci.c.backup \
           /usr/src/linux-headers-$(uname -r)/drivers/net/wireless/mediatek/mt76/mt7921/pci.c
   
   # Пересоберите модуль
   cd /usr/src/linux-headers-$(uname -r)/
   sudo make M=drivers/net/wireless/mediatek/mt76/mt7921 modules
   sudo make M=drivers/net/wireless/mediatek/mt76/mt7921 modules_install
   sudo depmod -a
   sudo reboot
   ```

---

**Версия документа:** 1.0.0  
**Последнее обновление:** 2026-02-12
