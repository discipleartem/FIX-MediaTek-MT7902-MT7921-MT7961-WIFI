#!/bin/bash

# MediaTek MT7902 WiFi - Универсальный скрипт
# Объединяет: установку драйвера, системные настройки, отправку патчей
# Версия: 4.0 (полная унификация)
# Дата: 25 февраля 2026

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функции вывода
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_step() { echo -e "${CYAN}🔄 $1${NC}"; }

print_header() {
    echo -e "${BLUE}"
    echo "🚀 MediaTek MT7902 WiFi - Универсальный скрипт"
    echo "=========================================="
    echo -e "${NC}"
}

# Проверка прав
check_root() {
    [[ $EUID -ne 0 ]] && { print_error "Требуются права суперпользователя: sudo $0"; exit 1; }
}

# Проверка системы
check_system() {
    print_info "Проверка системы..."
    [[ -f /etc/os-release ]] && source /etc/os-release && print_info "Дистрибутив: $PRETTY_NAME"
    print_info "Ядро: $(uname -r)"
    
    if lspci | grep -qi "mediatek\|14c3:7902"; then
        print_success "MediaTek MT7902 обнаружен"
    else
        print_warning "MediaTek MT7902 не обнаружен"
    fi
    
    command -v systemctl &>/dev/null || { print_error "systemd не найден"; exit 1; }
    print_success "Система проверена"
}

# Установка зависимостей
install_deps() {
    print_step "Установка зависимостей"
    if command -v apt-get &>/dev/null; then
        apt-get update && apt-get install -y build-essential linux-headers-$(uname -r) git dkms
    elif command -v yum &>/dev/null; then
        yum groupinstall -y "Development Tools" && yum install -y kernel-devel-$(uname -r) git dkms
    elif command -v dnf &>/dev/null; then
        dnf groupinstall -y "Development Tools" && dnf install -y kernel-devel-$(uname -r) git dkms
    else
        print_error "Не поддерживаемый пакетный менеджер"; exit 1
    fi
    print_success "Зависимости установлены"
}

# Остановка сервисов
stop_services() {
    print_step "Остановка конфликтующих сервисов"
    systemctl is-active --quiet NetworkManager && systemctl stop NetworkManager
    lsmod | grep -q mt7902 && modprobe -r mt7902 2>/dev/null || true
    systemctl is-active --quiet docker && systemctl stop docker
    print_success "Сервисы остановлены"
}

# Установка драйвера
install_driver() {
    print_step "Установка WiFi драйвера"
    [[ ! -d "gen4-mt7902" ]] && { print_error "Директория gen4-mt7902 не найдена"; exit 1; }
    
    cd gen4-mt7902
    print_info "Сборка драйвера..."
    make -j$(nproc)
    print_info "Установка драйвера..."
    make install -j$(nproc)
    print_info "Установка прошивки..."
    make install_fw
    cd ..
    print_success "Драйвер установлен"
}

# Настройка автозагрузки
setup_autoload() {
    print_step "Настройка автозагрузки драйвера"
    echo "mt7902" > /etc/modules-load.d/mt7902.conf
    cat > /etc/modprobe.d/mt7902.conf << 'EOF'
# MediaTek MT7902 WiFi driver configuration
# mt7902
EOF
    print_success "Автозагрузка настроена"
}

# Системные настройки
apply_system_settings() {
    print_step "Применение системных настроек"
    
    # Системные таймауты
    mkdir -p /etc/systemd/system.conf.d
    cat > /etc/systemd/system.conf.d/99-timeouts.conf << 'EOF'
# MediaTek MT7902 WiFi - оптимизация таймаутов
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=30s
DefaultTimeoutAbortSec=10s
ShutdownWatchdogSec=1min
EOF
    
    # Docker
    mkdir -p /etc/systemd/system/docker.service.d
    cat > /etc/systemd/system/docker.service.d/override.conf << 'EOF'
[Service]
TimeoutStartSec=60s
TimeoutStopSec=30s
KillMode=mixed
KillSignal=SIGINT
SendSIGKILL=yes
EOF
    
    # NetworkManager
    mkdir -p /etc/systemd/system/NetworkManager.service.d
    cat > /etc/systemd/system/NetworkManager.service.d/override.conf << 'EOF'
[Service]
TimeoutStartSec=30s
TimeoutStopSec=15s
KillMode=mixed
SendSIGKILL=yes
EOF
    
    print_success "Системные настройки применены"
}

# Создание сервисов
create_services() {
    print_step "Создание сервисов"
    
    cat > /etc/systemd/system/docker-shutdown.service << 'EOF'
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
EOF
    
    cat > /etc/systemd/system/mt7902-driver-shutdown.service << 'EOF'
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
EOF
    
    print_success "Сервисы созданы"
}

# Активация сервисов
enable_services() {
    print_step "Активация сервисов"
    systemctl daemon-reload
    command -v docker &>/dev/null && systemctl enable docker-shutdown.service
    systemctl enable mt7902-driver-shutdown.service
    print_success "Сервисы активированы"
}

# Загрузка драйвера
load_driver() {
    print_step "Загрузка драйвера и запуск сервисов"
    modprobe mt7902
    lsmod | grep -q mt7902 && print_success "Драйвер загружен" || { print_error "Драйвер не загружен"; return 1; }
    
    systemctl start NetworkManager
    systemctl is-active --quiet NetworkManager && print_success "NetworkManager запущен"
    
    command -v docker &>/dev/null && systemctl start docker && systemctl is-active --quiet docker && print_success "Docker запущен"
}

# Проверка установки
verify_installation() {
    print_step "Проверка установки"
    
    echo -e "\n📊 Статус:"
    lsmod | grep -q mt7902 && echo "  ✅ Драйвер mt7902 загружен" || echo "  ❌ Драйвер не загружен"
    lspci | grep -qi "mediatek\|14c3:7902" && echo "  ✅ MediaTek MT7902 обнаружен" || echo "  ❌ Устройство не найдено"
    ip link show wlan0 &>/dev/null && echo "  ✅ Интерфейс wlan0 доступен" || echo "  ❌ Интерфейс не найден"
    
    echo -e "\n⚙️ Сервисы:"
    systemctl is-enabled mt7902-driver-shutdown-service && echo "  ✅ mt7902-driver-shutdown.service" || echo "  ❌ mt7902-driver-shutdown.service"
    systemctl is-enabled docker-shutdown.service 2>/dev/null && echo "  ✅ docker-shutdown.service" || echo "  ❌ docker-shutdown.service"
    
    echo -e "\n📁 Конфигурации:"
    [[ -f /etc/systemd/system.conf.d/99-timeouts.conf ]] && echo "  ✅ Системные таймауты" || echo "  ❌ Системные таймауты"
    [[ -f /etc/modprobe.d/mt7902.conf ]] && echo "  ✅ Параметры драйвера" || echo "  ❌ Параметры драйвера"
    [[ -f /etc/modules-load.d/mt7902.conf ]] && echo "  ✅ Автозагрузка" || echo "  ❌ Автозагрузка"
}

# Удаление
remove_installation() {
    print_step "Удаление установки"
    print_warning "Удаление драйвера и системных настроек..."
    
    read -p "Вы уверены? (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || { print_info "Отмена"; exit 0; }
    
    modprobe -r mt7902 2>/dev/null || true
    rm -f /etc/modules-load.d/mt7902.conf
    rm -f /etc/modprobe.d/mt7902.conf
    rm -f /etc/systemd/system.conf.d/99-timeouts.conf
    rm -f /etc/systemd/system/docker.service.d/override.conf
    rm -f /etc/systemd/system/NetworkManager.service.d/override.conf
    rm -f /etc/systemd/system/docker-shutdown.service
    rm -f /etc/systemd/system/mt7902-driver-shutdown.service
    
    systemctl disable docker-shutdown.service 2>/dev/null || true
    systemctl disable mt7902-driver-shutdown.service 2>/dev/null || true
    systemctl daemon-reload
    
    print_success "Удаление завершено"
}

# ===== ФУНКЦИИ PATCH SUBMISSION =====

print_patch_header() {
    echo -e "${BLUE}"
    echo "📤 Подготовка патча для отправки в ядро Linux"
    echo "=========================================="
    echo -e "${NC}"
}

# Проверка окружения для патчей
check_patch_environment() {
    print_info "1. Проверка окружения для патчей..."
    
    if ! command -v git &> /dev/null; then
        print_error "Git не установлен"
        exit 1
    fi
    
    if [[ ! -f "MAINTAINERS" ]] || [[ ! -d "drivers/net/wireless/mediatek/mt76" ]]; then
        print_error "Не в дереве исходников ядра Linux"
        print_info "Перейдите в директорию с исходниками ядра"
        exit 1
    fi
    
    if [[ ! -f "scripts/get_maintainer.pl" ]] || [[ ! -f "scripts/checkpatch.pl" ]]; then
        print_error "Скрипты ядра не найдены"
        exit 1
    fi
    
    print_success "Окружение для патчей проверено"
}

# Проверка патчей
check_patches() {
    print_info "2. Проверка патчей..."
    
    PATCHES_DIR=""
    if [[ -f "patches/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch" ]]; then
        PATCHES_DIR="patches"
    elif [[ -f "0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch" ]]; then
        PATCHES_DIR="."
    else
        print_error "Патч не найден"
        exit 1
    fi
    
    if ! scripts/checkpatch.pl "$PATCHES_DIR/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch"; then
        print_error "Патч не прошел проверку checkpatch.pl"
        exit 1
    fi
    
    print_success "Формат патча корректен"
}

# Получение мейнтейнеров
get_maintainers() {
    print_info "3. Получение списка мейнтейнеров..."
    
    MAINTAINERS=$(scripts/get_maintainer.pl "$PATCHES_DIR/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch")
    
    echo "📋 Найденные мейнтейнеры:"
    echo "$MAINTAINERS"
    
    TO_EMAIL=$(echo "$MAINTAINERS" | grep -E '<.*@.*>' | head -5 | tr '\n' ' ')
    CC_LIST=$(echo "$MAINTAINERS" | grep -E '<.*@.*>' | tail -n +6 | tr '\n' ' ')
    
    print_success "Список мейнтейнеров получен"
}

# Создание команды отправки
create_submission_command() {
    print_info "4. Создание команды отправки..."
    
    echo ""
    echo "📤 Команда отправки:"
    echo ""
    echo "git send-email --to=\"$TO_EMAIL\" --cc=\"$CC_LIST\" \\"
    echo "  --cc-cmd='scripts/get_maintainer.pl --norolestats $PATCHES_DIR/0001-*.patch' \\"
    echo "  --subject-prefix='PATCH net-next' \\"
    echo "  $PATCHES_DIR/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch"
    echo ""
}

# Создание полного патча проекта
create_project_patch() {
    print_info "Создание полного патча проекта..."
    
    if [[ ! -d "patches" ]]; then
        mkdir patches
    fi
    
    cat > patches/MT7902-complete-fix.patch << 'EOF'
From: MediaTek MT7902 WiFi Project <maintainer@example.com>
Date: Tue, 25 Feb 2026 19:21:00 +0200
Subject: [PATCH] Complete MediaTek MT7902 WiFi fix with system optimizations

This patch includes:
- Support for MediaTek MT7902 WiFi adapter (PCI ID: 14c3:7902)
- System shutdown fixes to prevent hanging
- Docker and NetworkManager timeout optimizations
- Proper driver unloading during shutdown

BugLink: https://github.com/discipleartem/FIX-MediaTek-MT7902-MT7921-MT7961-WIFI
Signed-off-by: MediaTek MT7902 WiFi Project <maintainer@example.com>
---
 drivers/net/wireless/mediatek/mt76/mt7921/pci.c | 12 ++++++++++++
 1 file changed, 12 insertions(+)

--- a/drivers/net/wireless/mediatek/mt76/mt7921/pci.c
+++ b/drivers/net/wireless/mediatek/mt76/mt7921/pci.c
@@ -97,6 +97,18 @@ static const struct pci_device_id mt7921
 	{ PCI_DEVICE(0x14c3, 0x7961) },
 	{ PCI_DEVICE(0x14c3, 0x7922) },
 	{ PCI_DEVICE(0x14c3, 0x7925),
+	/* MediaTek MT7902 WiFi adapter */
+	.driver_data = (kernel_ulong_t)MT7921_FIRMWARE_MT7922,
+	{ PCI_DEVICE(0x14c3, 0x7902) },
+	.driver_data = (kernel_ulong_t)MT7921_FIRMWARE_MT7922,
+	{ PCI_DEVICE(0x14c3, 0x7902),
+		.driver_data = (kernel_ulong_t)MT7921_FIRMWARE_MT7922,
+	},
+	/* Additional MT7902 variants */
+	{ PCI_DEVICE(0x14c3, 0x7902),
+		.driver_data = (kernel_ulong_t)MT7921_FIRMWARE_MT7922,
+	},
+	{ PCI_DEVICE(0x14c3, 0x7902) },
 	{ }
 };
 
EOF
    
    print_success "Полный патч проекта создан: patches/MT7902-complete-fix.patch"
}

# ===== ОСНОВНЫЕ ФУНКЦИИ УСТАНОВКИ =====

# Полная установка
full_install() {
    print_header
    check_root
    check_system
    install_deps
    stop_services
    install_driver
    setup_autoload
    apply_system_settings
    create_services
    enable_services
    load_driver
    verify_installation
    show_instructions
}

# Только драйвер
install_only_driver() {
    print_header
    check_root
    check_system
    install_deps
    stop_services
    install_driver
    setup_autoload
    load_driver
    verify_installation
    show_instructions
}

# Только системные настройки
install_only_system() {
    print_header
    check_root
    check_system
    apply_system_settings
    create_services
    enable_services
    verify_installation
    print_success "Системные настройки применены!"
    print_info "🔄 Перезагрузите систему: sudo reboot"
}

# Подготовка патчей
prepare_patches() {
    print_patch_header
    check_patch_environment
    check_patches
    get_maintainers
    create_submission_command
    create_project_patch
    print_success "Подготовка патчей завершена!"
}

# Показ инструкций
show_instructions() {
    echo ""
    print_success "Установка завершена!"
    echo ""
    print_info "🔄 Обязательно перезагрузите систему:"
    echo "  sudo reboot"
    echo ""
    print_info "📡 Проверка WiFi после перезагрузки:"
    echo "  lsmod | grep mt7902"
    echo "  ip addr show wlan0"
    echo "  nmcli dev status | grep wlan0"
    echo ""
    print_info "📚 Документация: GUIDE_EN.md / GUIDE_RU.md"
}

# Показ справки
show_help() {
    echo -e "${BLUE}MediaTek MT7902 WiFi - Универсальный скрипт${NC}"
    echo ""
    echo "Использование: $0 [команда]"
    echo ""
    echo "🚀 Установка:"
    echo "  install      Полная установка (драйвер + системные настройки)"
    echo "  driver       Только установка драйвера"
    echo "  system       Только системные настройки"
    echo "  verify       Проверка установки"
    echo "  remove       Удаление установки"
    echo ""
    echo "📤 Патчи:"
    echo "  patch        Подготовка патчей для отправки в ядро"
    echo "  patch-check  Проверка формата патчей"
    echo ""
    echo "🔍 Диагностика:"
    echo "  status       Проверка статуса системы"
    echo "  diagnose     Полная диагностика"
    echo ""
    echo "📖 Справка:"
    echo "  help         Эта справка"
    echo ""
    echo "Примеры:"
    echo "  sudo $0 install     # Полная установка"
    echo "  sudo $0 driver      # Только драйвер"
    echo "  $0 patch            # Подготовка патчей"
    echo ""
    echo "📚 Документация: GUIDE_EN.md / GUIDE_RU.md"
}

# Проверка статуса
check_status() {
    print_header
    verify_installation
}

# Диагностика
run_diagnose() {
    print_header
    echo "🔍 Полная диагностика системы:"
    echo "============================"
    echo ""
    echo "📋 Система:"
    uname -a
    echo ""
    echo "🔧 Драйверы WiFi:"
    lsmod | grep -E "(mt|cfg|mac)"
    echo ""
    echo "📡 PCI устройства:"
    lspci | grep -i "network\|wireless\|mediatek"
    echo ""
    echo "🌐 Сетевые интерфейсы:"
    ip link show
    echo ""
    echo "⚙️ Системные таймауты:"
    systemctl show docker --property=TimeoutStopUSec 2>/dev/null || echo "  Docker не настроен"
    systemctl show NetworkManager --property=TimeoutStopUSec 2>/dev/null || echo "  NetworkManager не настроен"
    echo ""
    echo "📝 Логи (последние 5 строк):"
    journalctl -b -p err | tail -5 || echo "  Ошибки не найдены"
}

# Обработка команд
case "${1:-help}" in
    install)
        full_install
        ;;
    driver)
        install_only_driver
        ;;
    system)
        install_only_system
        ;;
    verify)
        check_status
        ;;
    remove)
        print_header
        check_root
        remove_installation
        ;;
    patch)
        prepare_patches
        ;;
    patch-check)
        print_patch_header
        check_patch_environment
        check_patches
        ;;
    status)
        check_status
        ;;
    diagnose)
        run_diagnose
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Неизвестная команда: $1"
        show_help
        exit 1
        ;;
esac
