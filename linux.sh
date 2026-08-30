#!/bin/bash
# Универсальная настройка сканера в ALT Linux (USB и сетевой)

set -e  # остановка при ошибке

# Проверка прав
if [ "$EUID" -ne 0 ]; then
    echo "❌ Запустите скрипт с sudo: sudo ./setup-scanner.sh"
    exit 1
fi

USER_NAME=${SUDO_USER:-$USER}
echo "👤 Настройка для пользователя: $USER_NAME"

echo "=== 🔧 Установка пакетов ==="
apt-get update
apt-get install -y sane sane-utils simple-scan

# Пакет для сетевых сканеров (поддержка eSCL, AirScan)
apt-get install -y sane-airscan || echo "⚠️  Пакет sane-airscan не найден, возможно, сетевые сканеры будут работать через другие бэкенды."

echo "=== 👥 Добавление пользователя в группы ==="
usermod -aG lp $USER_NAME
usermod -aG scanner $USER_NAME

echo "=== 🔍 Поиск доступных сканеров ==="
sane-find-scanner -q
echo "Список устройств:"
scanimage -L

# Функция выбора и запоминания устройства
choose_device() {
    local devices
    devices=$(scanimage -L | grep -E "^device" | sed -E "s/^device \`([^\`]+)'.*/\1/")
    if [ -z "$devices" ]; then
        echo "❌ Сканеры не найдены. Проверьте подключение и совместимость."
        return 1
    fi
    IFS=$'\n' read -d '' -r -a dev_array <<< "$devices"
    count=${#dev_array[@]}
    echo "Доступные устройства:"
    for i in "${!dev_array[@]}"; do
        echo "$((i+1))) ${dev_array[$i]}"
    done
    read -p "Введите номер устройства для запоминания (или 0 для пропуска): " choice
    if [ "$choice" -eq 0 ]; then
        echo "Пропускаем запоминание."
        return 0
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
        selected="${dev_array[$((choice-1))]}"
        echo "export SANE_DEFAULT_DEVICE=\"$selected\"" >> /home/$USER_NAME/.profile
        echo "✅ Устройство '$selected' запомнено в ~/.profile"
        echo "⚠️  Чтобы изменения вступили силу, выйдите из системы и зайдите снова (или выполните: source ~/.profile)"
    else
        echo "❌ Неверный номер. Попробуйте снова."
        choose_device
    fi
}

# Предложение запомнить устройство
read -p "Хотите запомнить выбранный сканер, чтобы не выбирать его каждый раз? (y/n): " remember
if [[ "$remember" =~ ^[Yy]$ ]]; then
    choose_device
else
    echo "Позже вы можете вручную добавить переменную SANE_DEFAULT_DEVICE в ~/.profile"
fi

# Ручное добавление сетевого сканера по IP
echo ""
read -p "Если у вас сетевой сканер с известным IP-адресом, введите его (например, 192.168.1.100). Иначе нажмите Enter: " ipaddr
if [ -n "$ipaddr" ]; then
    echo "Добавляем IP в /etc/sane.d/net.conf ..."
    echo "$ipaddr" >> /etc/sane.d/net.conf
    if ! grep -q "^net" /etc/sane.d/dll.conf; then
        echo "net" >> /etc/sane.d/dll.conf
        echo "Бэкенд 'net' активирован."
    fi
    echo "✅ IP $ipaddr добавлен. Проверьте работу сканера после перезагрузки сеанса."
fi

echo ""
echo "=== ✅ Настройка завершена ==="
echo "1️⃣ Перезагрузите сеанс пользователя $USER_NAME (выйдите и зайдите заново)."
echo "2️⃣ После перезагрузки проверьте сканер командой: scanimage -L"
echo "3️⃣ Запустите Simple Scan из меню приложений."
