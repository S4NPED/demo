#!/bin/bash
# Полная настройка BR-RTR для демонстрационного экзамена 2026
# Debian 13

set -e

echo "========================================"
echo "Настройка BR-RTR (Debian 13)"
echo "========================================"

apt update
apt upgrade -y

# 2. Настройка имени хоста
echo "2. Настройка имени хоста..."
hostnamectl set-hostname br-rtr.au-team.irpo

# 6. Настройка GRE туннеля
echo "6. Настройка GRE туннеля..."
apt install -y network-manager

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

auto gre1
iface gre1 inet tunnel
address 10.10.0.2
netmask 255.255.255.252
mode gre
local 172.16.2.2
endpoint 172.16.1.2
ttl 64

post-up nft -f /etc/nftables.conf
post-up ip link set gre1 up

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

# 8. Создание пользователя net_admin
echo "8. Создание пользователей..."
useradd -m -s /bin/bash net_admin -U
usermod -aG sudo net_admin
echo "net_admin:P@ssw0rd" | chpasswd

# Настройка sudo без пароля
echo "net_admin ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

# 7. Установка и настройка FRR (OSPF)
echo "7. Установка FRR для OSPF..."
apt install -y frr

# Включаем OSPF демон
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons

# 3. Перезапуск FRR
echo "Перезапускаем FRR..."
systemctl restart frr

# 4. Настройка OSPF через vtysh
echo "Настраиваем OSPF..."
vtysh << EOF
conf t
router ospf
router-id 2.2.2.2
no passive-interface default
network 192.168.200.0/28 area 0
network 10.10.0.0/30 area 0
area 0 authentication
int tun1
no ip ospf passive
no ip ospf network broadcast
ip ospf authentication
ip ospf authentication-key password
exit
exit
wr
EOF

# 9. Настройка часового пояса
echo "9. Настройка часового пояса..."
timedatectl set-timezone Asia/Krasnoyarsk

echo "========================================"
echo "Настройка BR-RTR завершена!"
echo "========================================"
