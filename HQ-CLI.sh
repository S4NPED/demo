#!/bin/bash
# Полная настройка HQ-CLI для демонстрационного экзамена 2026
# Debian 13

set -e

echo "========================================"
echo "Настройка HQ-CLI (Debian 13)"
echo "========================================"

# 1. Настройка репозиториев
echo "1. Настройка репозиториев..."
sed -i '1s/^/#/' /etc/apt/sources.list
apt update
apt upgrade -y

# 2. Настройка имени хоста
echo "2. Настройка имени хоста..."
hostnamectl set-hostname hq-cli.au-team.irpo

# 3. Настройка сети через DHCP
echo "3. Настройка сети (DHCP)..."
cat > /etc/network/interfaces << 'EOF'
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto ens3
iface ens3 inet dhcp
EOF

# 4. Настройка DNS
echo "4. Настройка DNS..."
cat > /etc/resolv.conf << 'EOF'
nameserver 192.168.100.2
search au-team.irpo
EOF

# 5. Настройка часового пояса
echo "5. Настройка часового пояса..."
timedatectl set-timezone Asia/Krasnoyarsk

# 6. Установка необходимых утилит
echo "6. Установка утилит..."
apt install -y \
    openssh-client \
    dnsutils \
    net-tools \
    iputils-ping \
    curl \
    wget

# 7. Настройка SSH клиента
echo "7. Настройка SSH клиента..."
cat > /etc/ssh/ssh_config.d/custom.conf << 'EOF'
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

# 8. Перезапуск сети
echo "8. Перезапуск сети..."
systemctl restart networking

# 9. Ожидание получения IP по DHCP
echo "9. Ожидание DHCP..."
sleep 5

# 10. Создание скрипта проверки
cat > /usr/local/bin/check-hq-cli << 'EOF'
#!/bin/bash
echo "=== Статус HQ-CLI ==="
echo "1. Интерфейсы:"
ip -br a
echo -e "\n2. Маршруты:"
ip route
echo -e "\n3. DNS:"
cat /etc/resolv.conf
echo -e "\n4. DHCP:"
journalctl -u systemd-networkd -n 10 --no-pager 2>/dev/null | grep DHCP || dhclient -v ens3 2>&1 | tail -5
echo -e "\n5. Ping тесты:"
for target in 192.168.100.1 192.168.100.2 192.168.200.2 google.com; do
    echo -n "Ping $target: "
    ping -c 1 -W 1 $target >/dev/null 2>&1 && echo "OK" || echo "FAIL"
done
echo -e "\n6. SSH тест к HQ-SRV:"
timeout 2 ssh -o ConnectTimeout=1 -p 2026 shuser@192.168.100.2 "echo SSH доступен" 2>/dev/null && echo "SSH: OK" || echo "SSH: FAIL"
EOF

chmod +x /usr/local/bin/check-hq-cli

echo "========================================"
echo "Настройка HQ-CLI завершена!"
echo "========================================"
echo "Используйте: check-hq-cli для проверки"