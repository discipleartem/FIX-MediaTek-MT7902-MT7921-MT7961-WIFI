# Исправление WiFi адаптера MT7921 для Linux

## Проблема
WiFi адаптер MediaTek MT7921 (PCI ID: 14c3:7902) не распознается ядром Linux и отображается как "UNCLAIMED" устройство.

## Решение
Использовать драйвер gen4-mt7902 - разработанный сообществом драйвер на основе исходного кода MediaTek, который обеспечивает полную функциональность WiFi.

## Поддерживаемые устройства
- **MT7902** (PCI ID: 14c3:7902) - основная цель
- **MT7921** совместимые варианты
- **MT7961** совместимые устройства
- Другие WiFi чипы MediaTek Gen4

## Инструкции по установке

### Необходимые пакеты
```bash
sudo apt update
sudo apt install build-essential dkms linux-headers-$(uname -r) git
```

### Шаг 1: Клонирование репозитория драйвера
```bash
git clone https://github.com/hmtheboy154/gen4-mt7902
cd gen4-mt7902
```

### Шаг 2: Сборка и установка драйвера
```bash
make -j$(nproc)
sudo make install -j$(nproc)
```

### Шаг 3: Установка прошивки
```bash
sudo make install_fw
```

### Шаг 4: Загрузка драйвера
```bash
sudo modprobe mt7902
```

### Шаг 5: Включение автозагрузки (опционально)
```bash
echo "mt7902" | sudo tee -a /etc/modules-load.d/mt7902.conf
```

### Шаг 6: Перезагрузка
```bash
sudo reboot
```

## Проверка работы

После перезагрузки проверьте работу WiFi:

```bash
# Проверить статус устройств
nmcli device status

# Должен показать wlan0 как wifi устройство
# DEVICE  TYPE      STATE      CONNECTION
# wlan0   wifi      connected  ВашаСеть

# Сканирование сетей
nmcli device wifi list

# Должен показать доступные WiFi сети
```

## Возможности
- ✅ Полная WiFi функциональность (2.4GHz & 5GHz)
- ✅ Интеграция с NetworkManager
- ✅ Поддержка WPA/WPA2/WPA3
- ✅ Сканирование и подключение к WiFi сетям
- ✅ Поддержка P2P
- ✅ Автозагрузка при включении

## Известные проблемы
- WPA3 может иметь проблемы с iwd (используйте wpa_supplicant)
- Функциональность WiFi точки доступа может быть ограничена
- Сон/пробуждение может потребовать перезагрузки драйвера

## Устранение неполадок

### Если WiFi не обнаруживается:
```bash
# Проверить загрузку драйвера
lsmod | grep mt7902

# Проверить распознавание устройства
lspci -nn | grep 14c3:7902

# Перезагрузить драйвер
sudo rmmod mt7902
sudo modprobe mt7902
```

### Если NetworkManager не видит WiFi:
```bash
# Перезапустить NetworkManager
sudo systemctl restart NetworkManager

# Проверить тип устройства
nmcli device status
```

## Источник драйвера
Основан на: https://github.com/hmtheboy154/gen4-mt7902

Драйвер разработанный сообществом с модификациями исходного кода MediaTek для совместимости с Linux.

## Лицензия
Драйвер следует условиям лицензирования MediaTek и предоставляется "как есть" для использования сообществом.
