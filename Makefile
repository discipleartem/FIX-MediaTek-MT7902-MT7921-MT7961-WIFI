# Makefile для MediaTek MT7902 WiFi Driver
# Версия: 3.0 (рефакторинг)
# Поддержка: gen4-mt7902, базовые команды

# Переменные
KERNEL_VERSION := $(shell uname -r)
KERNEL_BUILD := /lib/modules/$(KERNEL_VERSION)/build
NPROC := $(shell nproc)
GEN4_DIR := gen4-mt7902
PATCH_DRIVER := mt7921e_simple_patch

# Цели по умолчанию
.PHONY: all install clean uninstall test diagnose help quick-install patch patch-check

# Сборка нашего патча драйвера
obj-m += $(PATCH_DRIVER).o

all: patch-driver
	@echo "🔧 Сборка завершена. Используйте 'make install' для установки"

# Сборка патча
patch-driver:
	@echo "📦 Сборка патча $(PATCH_DRIVER)..."
	$(MAKE) -C $(KERNEL_BUILD) M=$(PWD) modules
	@echo "✅ Патч собран"

# Сборка gen4 драйвера
gen4-driver:
	@echo "📦 Сборка gen4-mt7902 драйвера..."
	@if [ ! -d "$(GEN4_DIR)" ]; then \
		echo "❌ Директория $(GEN4_DIR) не найдена"; \
		exit 1; \
	fi
	cd $(GEN4_DIR) && $(MAKE) -j$(NPROC)
	@echo "✅ gen4-mt7902 драйвер собран"

# Установка gen4 драйвера
install-gen4:
	@echo "🚀 Установка gen4-mt7902 драйвера..."
	@if [ ! -d "$(GEN4_DIR)" ]; then \
		echo "❌ Директория $(GEN4_DIR) не найдена"; \
		exit 1; \
	fi
	cd $(GEN4_DIR) && sudo $(MAKE) install -j$(NPROC)
	cd $(GEN4_DIR) && sudo $(MAKE) install_fw
	@echo "✅ gen4-mt7902 драйвер установлен"

# Полная установка
install: gen4-driver install-gen4
	@echo "📋 Настройка автозагрузки..."
	echo "mt7902" | sudo tee /etc/modules-load.d/mt7902.conf
	@echo "📋 Загрузка драйвера..."
	sudo modprobe -r mt7902 || true
	sudo modprobe mt7902
	@echo ""
	@echo "🎉 Установка завершена!"
	@echo "📡 Проверка WiFi: nmcli dev status | grep wlan0"
	@echo "🔄 Перезагрузка: sudo reboot"

# Быстрая установка через скрипт
quick-install:
	@echo "🚀 Быстрая установка через скрипт..."
	sudo ./mt7902.sh install

# Проверка статуса
check-status:
	@echo "📊 Статус MediaTek MT7902:"
	@echo ""
	@echo "🔧 Драйвер:"
	@lsmod | grep mt7902 || echo "  ❌ Драйвер не загружен"
	@echo ""
	@echo "📡 Устройство:"
	@lspci | grep -i "mediatek\|7902" || echo "  ❌ Устройство не найдено"
	@echo ""
	@echo "🌐 Интерфейс:"
	@ip link show | grep wlan0 || echo "  ❌ Интерфейс не найден"
	@echo ""
	@echo "⚙️ Сервисы:"
	@systemctl is-enabled mt7902-driver-shutdown.service 2>/dev/null && echo "  ✅ mt7902-driver-shutdown.service" || echo "  ❌ mt7902-driver-shutdown.service"
	@systemctl is-enabled docker-shutdown.service 2>/dev/null && echo "  ✅ docker-shutdown.service" || echo "  ❌ docker-shutdown.service"

# Тестирование
test: check-status
	@echo ""
	@echo "🧪 Тестирование WiFi..."
	@if lsmod | grep -q mt7902; then \
		echo "✅ Драйвер загружен"; \
		if ip link show wlan0 &>/dev/null; then \
			echo "✅ Интерфейс wlan0 доступен"; \
			echo "� Попытка сканирования..."; \
			iwlist wlan0 scan 2>/dev/null | head -3 || iw dev wlan0 scan | head -3 || echo "⚠️ Сканирование не удалось"; \
		else \
			echo "❌ Интерфейс не найден"; \
		fi; \
	else \
		echo "❌ Драйвер не загружен"; \
	fi

# Диагностика
diagnose:
	@echo "🔍 Полная диагностика системы:"
	@echo "============================"
	@echo ""
	@echo "📋 Система:"
	@uname -a
	@echo ""
	@echo "🔧 Драйверы WiFi:"
	@lsmod | grep -E "(mt|cfg|mac)"
	@echo ""
	@echo "📡 PCI устройства:"
	@lspci | grep -i "network\|wireless\|mediatek"
	@echo ""
	@echo "🌐 Сетевые интерфейсы:"
	@ip link show
	@echo ""
	@echo "⚙️ Системные таймауты:"
	@systemctl show docker --property=TimeoutStopUSec 2>/dev/null || echo "  Docker не настроен"
	@systemctl show NetworkManager --property=TimeoutStopUSec 2>/dev/null || echo "  NetworkManager не настроен"
	@echo ""
	@echo "📝 Логи (последние 5 строк):"
	@journalctl -b -p err | tail -5 || echo "  Ошибки не найдены"

# Очистка
clean:
	@echo "� Очистка..."
	$(MAKE) -C $(KERNEL_BUILD) M=$(PWD) clean
	@if [ -d "$(GEN4_DIR)" ]; then \
		cd $(GEN4_DIR) && $(MAKE) clean; \
	fi
	@echo "✅ Очистка завершена"

# Удаление
uninstall:
	@echo "🗑️ Удаление драйвера и настроек..."
	@echo "📋 Выгрузка драйвера..."
	sudo modprobe -r mt7902 || true
	@echo "📋 Удаление файлов..."
	sudo rm -f /etc/modules-load.d/mt7902.conf
	sudo rm -f /etc/modprobe.d/mt7902.conf
	sudo rm -f /etc/systemd/system.conf.d/99-timeouts.conf
	sudo rm -f /etc/systemd/system/docker.service.d/override.conf
	sudo rm -f /etc/systemd/system/NetworkManager.service.d/override.conf
	sudo rm -f /etc/systemd/system/docker-shutdown.service
	sudo rm -f /etc/systemd/system/mt7902-driver-shutdown.service
	@echo "� Отключение сервисов..."
	sudo systemctl disable docker-shutdown.service 2>/dev/null || true
	sudo systemctl disable mt7902-driver-shutdown.service 2>/dev/null || true
	sudo systemctl daemon-reload
	@echo "✅ Удаление завершено"

# Подготовка патчей
patch:
	@echo "📤 Подготовка патчей для отправки в ядро..."
	./mt7902.sh patch

# Проверка патчей
patch-check:
	@echo "🔍 Проверка формата патчей..."
	./mt7902.sh patch-check

# Помощь
help:
	@echo "🔧 Makefile для MediaTek MT7902 WiFi Driver"
	@echo "=========================================="
	@echo ""
	@echo "📦 Сборка:"
	@echo "  all              - Сборка патча драйвера"
	@echo "  gen4-driver      - Сборка gen4-mt7902 драйвера"
	@echo "  patch-driver     - Сборка нашего патча"
	@echo ""
	@echo "🚀 Установка:"
	@echo "  install          - Полная установка драйвера"
	@echo "  install-gen4     - Установка gen4-mt7902"
	@echo "  quick-install    - Быстрая установка через скрипт"
	@echo ""
	@echo "🔍 Проверка:"
	@echo "  check-status     - Проверка статуса"
	@echo "  test             - Тестирование драйвера"
	@echo "  diagnose         - Полная диагностика"
	@echo ""
	@echo "🧹 Обслуживание:"
	@echo "  clean            - Очистка"
	@echo "  uninstall        - Удаление"
	@echo ""
	@echo "📖 Документация:"
	@echo "  GUIDE.md         - Полное руководство"
	@echo "  help             - Эта справка"
	@echo ""
	@echo "🎯 Быстрый старт:"
	@echo "  make quick-install"
	@echo "  make check-status"
	@echo "  make test"
	@echo ""
	@echo "📤 Патчи:"
	@echo "  make patch        # Подготовка патчей"
	@echo "  make patch-check  # Проверка патчей"
