# MediaTek MT7902 WiFi - Полное руководство

## 🎯 Обзор

Решение для WiFi адаптера MediaTek MT7902 (PCI ID: 14c3:7902) на Linux. Включает драйвер, системные оптимизации и исправление проблем зависания.

## 🚀 Быстрый старт

```bash
# Полная установка
sudo ./mt7902.sh install

# Перезагрузка
sudo reboot

# Проверка WiFi
lsmod | grep mt7902
nmcli dev status | grep wlan0
```

## 📡 Устройство и драйвер

### Характеристики
- **Устройство:** MediaTek MT7902 WiFi адаптер
- **PCI ID:** 14c3:7902
- **Драйвер:** mt7902 (gen4-mt7902 community driver)
- **Интерфейс:** wlan0

### Проверка драйвера
```bash
# Загружен ли модуль
lsmod | grep mt7902

# Устройство PCI
lspci | grep -i "mediatek\|7902"

# Проверка интерфейса
ip addr show wlan0

# Статус WiFi
nmcli dev status | grep wlan0
```

### Проблемы и решения

#### 1. Драйвер не загружается
```bash
# Перезагрузить драйвер
sudo modprobe -r mt7902
sudo modprobe mt7902

# Перезапустить NetworkManager
sudo systemctl restart NetworkManager
```

#### 2. Низкая скорость WiFi
```bash
# Установить правильный регион
sudo iw reg set US

# Проверить поддерживаемые частоты
iw dev wlan0 info | grep freq
```

## ⚙️ Системные оптимизации

### Проблема: зависание при выключении

Система зависала при выключении из-за:
- Бесконечных таймаутов Docker (`TimeoutStopUSec=infinity`)
- Проблем с выгрузкой WiFi драйвера mt7902
- Слишком долгих таймаутов NetworkManager

### Решение: оптимизация таймаутов

#### Системные таймауты (30 секунд)
```bash
# /etc/systemd/system.conf.d/99-timeouts.conf
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=30s
DefaultTimeoutAbortSec=10s
ShutdownWatchdogSec=1min
```

#### Docker оптимизация (30 секунд)
```bash
# /etc/systemd/system/docker.service.d/override.conf
[Service]
TimeoutStartSec=60s
TimeoutStopSec=30s
KillMode=mixed
KillSignal=SIGINT
SendSIGKILL=yes
```

#### NetworkManager оптимизация (15 секунд)
```bash
# /etc/systemd/system/NetworkManager.service.d/override.conf
[Service]
TimeoutStartSec=30s
TimeoutStopSec=15s
KillMode=mixed
SendSIGKILL=yes
```

### Сервисы для корректного выключения

#### Docker shutdown сервис
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

#### WiFi драйвер сервис
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

## 🛠️ Установка и использование

### Универсальный скрипт

Проект теперь использует единый скрипт `mt7902.sh` для всех операций:

```bash
# Полная установка (драйвер + системные настройки)
sudo ./mt7902.sh install

# Только драйвер
sudo ./mt7902.sh driver

# Только системные настройки
sudo ./mt7902.sh system

# Проверка установки
./mt7902.sh verify

# Удаление
sudo ./mt7902.sh remove

# Подготовка патчей для отправки в ядро
./mt7902.sh patch

# Проверка формата патчей
./mt7902.sh patch-check

# Статус системы
./mt7902.sh status

# Полная диагностика
./mt7902.sh diagnose

# Справка
./mt7902.sh help
```

### Makefile команды

```bash
# Быстрая установка
make quick-install

# Полная установка
sudo make install

# Подготовка патчей
make patch

# Проверка патчей
make patch-check

# Проверка статуса
make check-status

# Тестирование
make test

# Диагностика
make diagnose

# Очистка
make clean

# Удаление
sudo make uninstall

# Помощь
make help
```

## 🔍 Диагностика

### Проверка системы
```bash
# Статус драйвера
lsmod | grep mt7902

# Устройство
lspci | grep -i "mediatek\|7902"

# Интерфейс
ip addr show wlan0

# Сервисы
systemctl status mt7902-driver-shutdown.service
systemctl status docker-shutdown.service

# Таймауты
systemctl show docker --property=TimeoutStopUSec
systemctl show NetworkManager --property=TimeoutStopUSec
```

### Диагностика через скрипты
```bash
# Проверка установки
./mt7902.sh verify

# Полная диагностика
./mt7902.sh diagnose

# Проверка статуса
./mt7902.sh status

# Проверка патчей
./mt7902.sh patch-check
```

### Устранение проблем

#### WiFi не работает
```bash
# 1. Проверка драйвера
lsmod | grep mt7902

# 2. Перезагрузка драйвера
sudo modprobe -r mt7902 && sudo modprobe mt7902

# 3. Перезапуск NetworkManager
sudo systemctl restart NetworkManager

# 4. Проверка устройства
lspci | grep -i "mediatek\|7902"
```

#### Система зависает при выключении
```bash
# 1. Проверка сервисов
systemctl status mt7902-driver-shutdown.service
systemctl status docker-shutdown.service

# 2. Проверка таймаутов
systemctl show --property=DefaultTimeoutStopUSec

# 3. Проверка конфигурации
cat /etc/systemd/system.conf.d/99-timeouts.conf
```

#### Docker контейнеры останавливаются долго
```bash
# 1. Проверка Docker таймаутов
systemctl show docker --property=TimeoutStopUSec

# 2. Проверка сервиса
systemctl status docker-shutdown.service

# 3. Ручная остановка
sudo docker stop $(docker ps -q)
```

## 📋 Требования

### Система
- **ОС:** Ubuntu/Debian (рекомендовано), CentOS/RHEL, Fedora
- **Ядро:** Linux 5.4+ (поддержка mt7902)
- **Пакеты:** build-essential, linux-headers, git, dkms

### Программы
- **systemd** для управления сервисами
- **NetworkManager** для управления сетью
- **Docker** опционально, для оптимизации контейнеров

## 🎯 Результаты

### После установки
- **📡 WiFi работает** - MediaTek MT7902 полнофункционален
- **⚡ Быстрое выключение** - 15-30 секунд вместо зависания
- **🐳 Docker останавливается быстро** - 30 секунд таймаут
- **🌐 Сеть стабильна** - NetworkManager оптимизирован
- **🔄 Автозагрузка** - драйвер загружается при старте

### Сравнение
| Параметр | До установки | После установки |
|----------|---------------|----------------|
| WiFi | ❌ Не работает | ✅ Полностью функционален |
| Выключение | ❌ Зависание | ✅ 15-30 секунд |
| Docker | ❌ Бесконечный таймаут | ✅ 30 секунд |
| NetworkManager | ❌ Долгая остановка | ✅ 15 секунд |
| Автозагрузка | ❌ Отсутствует | ✅ Настроена |

## 🔄 Обслуживание

### Обновление драйвера
```bash
# Пересборка и установка
make clean
make gen4-driver
sudo make install-gen4
```

### Сброс настроек
```bash
# Удаление и повторная установка
sudo ./mt7902.sh remove
sudo ./mt7902.sh install
```

### Проверка версий
```bash
# Версия ядра
uname -r

# Версия драйвера
modinfo mt7902 | grep version

# Версия проекта
git log -1 --oneline
```

## 📞 Поддержка

### Быстрая помощь
```bash
# Диагностика проблем
./mt7902.sh diagnose

# Проверка статуса
./mt7902.sh status

# Справка
./mt7902.sh help
make help
```

### Отчеты о проблемах
- **GitHub Issues:** Сообщить о проблеме
- **Диагностика:** Используйте `make diagnose` для сбора информации

### Полезные команды
```bash
# Проверка WiFi
nmcli dev wifi list

# Логи ошибок
journalctl -b -p err | tail -10

# Логи драйвера
journalctl -b | grep -i "mt7902\|mediatek"

# Статус сервисов
systemctl list-units --type=service --state=failed
```

## 📄 Структура проекта

```
FIX-MediaTek-MT7902-MT7921-MT7961-WIFI/
├── 🚀 mt7902.sh                    # Универсальный скрипт (установка + патчи)
├── 🔨 Makefile                       # Основные команды
├── 📦 gen4-mt7902/                   # Community драйвер
├── 🩹 patches/                       # Патчи для ядра
├── 📚 GUIDE_EN.md                    # Английское руководство
├── 📚 GUIDE_RU.md                    # Русское руководство
├── 📋 README.md                      # Краткое описание
└── 📄 LICENSE                        # Лицензия
```

## 🎉 Готово к использованию!

Запустите `sudo ./mt7902.sh install` для полной установки драйвера и системных оптимизаций.

**Ключевые команды:**
- `sudo ./mt7902.sh install` - полная установка
- `./mt7902.sh patch` - подготовка патчей
- `./mt7902.sh diagnose` - диагностика проблем
- `./mt7902.sh help` - справка
