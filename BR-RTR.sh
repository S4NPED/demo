#!/bin/bash
# Полная настройка BR-RTR для демонстрационного экзамена 2026
# Debian 13

set -e

echo "========================================"
echo "Настройка BR-RTR (Debian 13)"
echo "========================================"

# 1. Настройка репозиториев
echo "1. Настройка репозиториев..."
sed -i '1s/^/#/' /etc/apt/sources.list
apt update
apt upgrade -y

# 2. Настройка имени хоста
echo "2. Настройка имени хоста..."
hostnamectl set-hostname br-rtr.au-team.irpo

# 3. Настройка сети
echo "3. Настройка сети..."
cat > /etc/network/interfaces << 'EOF'
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
address 172.16.2.2
netmask 255.255.255.240
gateway 172.16.2.1

auto ens4
iface ens4 inet static
address 192.168.200.1
netmask 255.255.255.240

post-up nft -f /etc/nftables.conf
EOF

# 4. Включение IP forwarding
echo "4. Включение IP forwarding..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/sysctl.conf
sysctl --system

# 5. Настройка nftables для NAT
echo "5. Настройка nftables..."
apt install -y nftables

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

# 6. Настройка GRE туннеля
echo "6. Настройка GRE туннеля..."
apt install -y network-manager

cat > /etc/network/interfaces.d/gre << 'EOF'
auto gre0
iface gre0 inet static
address 10.10.0.2
netmask 255.255.255.252
pre-up ip tunnel add gre0 mode gre local 172.16.2.2 remote 172.16.1.2 ttl 64
post-up ip link set gre0 up
EOF

# 7. Установка и настройка FRR (OSPF)
echo "7. Установка FRR для OSPF..."
apt install -y frr

# Включаем OSPF демон
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons

# Настраиваем FRR
cat > /etc/frr/frr.conf << 'EOF'
frr version 8.5.2
frr defaults traditional
hostname br-rtr.au-team.irpo
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
router ospf
 router-id 2.2.2.2
 network 192.168.200.0/28 area 0
 network 10.10.0.0/30 area 0
 area 0 authentication
!
interface gre0
 ip ospf authentication
 ip ospf authentication-key password
 no ip ospf passive
!
line vty
!
EOF

# 8. Создание пользователя net_admin
echo "8. Создание пользователей..."
useradd -m -s /bin/bash net_admin -U
usermod -aG sudo net_admin
echo "net_admin:P@ssw0rd" | chpasswd

# Настройка sudo без пароля
echo "net_admin ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

# 9. Настройка часового пояса
echo "9. Настройка часового пояса..."
timedatectl set-timezone Asia/Krasnoyarsk

# 10. Перезапуск служб
echo "10. Перезапуск служб..."
systemctl restart networking
systemctl restart frr

# 11. Создание скрипта проверки
cat > /usr/local/bin/check-br-rtr << 'EOF'
#!/bin/bash
echo "=== Статус BR-RTR ==="
echo "1. Интерфейсы:"
ip -br a
echo -e "\n2. Маршруты:"
ip route
echo -e "\n3. OSPF соседи:"
vtysh -c "show ip ospf neighbor" 2>/dev/null || echo "FRR не запущен"
echo -e "\n4. Ping тесты:"
for ip in 172.16.2.1 192.168.200.2 10.10.0.1 192.168.100.2; do
    echo -n "Ping $ip: "
    ping -c 1 -W 1 $ip >/dev/null 2>&1 && echo "OK" || echo "FAIL"
done
EOF

chmod +x /usr/local/bin/check-br-rtr

echo "========================================"
echo "Настройка BR-RTR завершена!"
echo "========================================"
echo "Используйте: check-br-rtr для проверки"