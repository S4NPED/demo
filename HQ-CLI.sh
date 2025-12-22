#!/bin/bash
# Полная настройка HQ-CLI для демонстрационного экзамена 2026
# Debian 13

echo "========================================"
echo "Настройка HQ-CLI (Debian 13)"
echo "========================================"

apt update

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

# 7. Настройка SSH клиента
echo "7. Настройка SSH клиента..."
cat > /etc/ssh/ssh_config << 'EOF'
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

echo "========================================"
echo "Настройка HQ-CLI завершена!"
echo "========================================"
rm -r /root/demo
