#!/bin/bash
# Полная настройка ISP для демонстрационного экзамена 2026
# Специальность 09.02.06 Сетевое и системное администрирование
# Debian 13

set -e  # Прерывать выполнение при ошибках

echo "========================================"
echo "Настройка ISP (Debian 13)"
echo "========================================"

# 2. Обновление системы
echo "2. Обновление системы..."
apt update
apt upgrade -y

# 3. Настройка имени хоста
echo "3. Настройка имени хоста..."
hostnamectl set-hostname isp.au-team.irpo

# 4. Настройка сети
echo "4. Настройка сети..."

# Создаем backup оригинального файла
cp /etc/network/interfaces /etc/network/interfaces.backup

# Создаем новый конфигурационный файл
cat > /etc/network/interfaces << 'EOF'
# This file describes the network interfaces available
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# Интерфейс к магистральному провайдеру (DHCP)
auto ens3
iface ens3 inet dhcp

# Интерфейс к HQ-RTR
auto ens4
iface ens4 inet static
address 172.16.1.1
netmask 255.255.255.240

# Интерфейс к BR-RTR
auto ens5
iface ens5 inet static
address 172.16.2.1
netmask 255.255.255.240

post-up nft -f /etc/nftables.conf
EOF

echo "Файл /etc/network/interfaces настроен"

# 5. Включение IP forwarding
echo > /etc/sysctl.d/sysctl.conf
sed -i '1i net.ipv4.ip_forward=1' /etc/sysctl.d/sysctl.conf

# 6. Настройка nftables для NAT
echo "6. Настройка nftables..."

# Устанавливаем nftables если нет
apt install -y nftables

# Создаем конфигурацию nftables
cat > /etc/nftables.conf << 'EOF'
#!/usr/sbin/nft -f

flush ruleset

table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept
        meta l4proto { gre, ipip, ospf } counter return
        masquerade
    }
}

table inet filter {
    chain input {
        type filter hook input priority filter;
    }
    chain forward {
        type filter hook forward priority filter;
    }
    chain output {
        type filter hook output priority filter;
    }
}
EOF

echo "Конфигурация nftables создана"

# 10. Настройка часового пояса (Красноярск)
echo "10. Настройка часового пояса..."
timedatectl set-timezone Asia/Krasnoyarsk

echo "========================================"
echo "Настройка ISP завершена!"
echo "========================================"
