#!/bin/bash
# Полная настройка HQ-RTR для демонстрационного экзамена 2026
# Debian 13

set -e

echo "========================================"
echo "Настройка HQ-RTR (Debian 13)"
echo "========================================"

# 1. Настройка репозиториев
echo "1. Настройка репозиториев..."
apt update
apt upgrade -y

# 2. Настройка имени хоста
echo "2. Настройка имени хоста..."
hostnamectl set-hostname hq-rtr.au-team.irpo

# 3. Настройка базовой сети (без VLAN)
echo "3. Настройка базовой сети..."
cat > /etc/network/interfaces << 'EOF'
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
address 172.16.1.2
netmask 255.255.255.240
gateway 172.16.1.1

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

# 6. Установка Open vSwitch для VLAN
echo "6. Установка Open vSwitch..."
apt install -y openvswitch-switch

# 7. Настройка VLAN через OVS
echo "7. Настройка VLAN..."

# Создаем мост
ovs-vsctl add-br hq-sw

# Добавляем физические интерфейсы с тегами VLAN
ovs-vsctl add-port hq-sw ens4 tag=100
ovs-vsctl add-port hq-sw ens5 tag=200
ovs-vsctl add-port hq-sw ens6 tag=999

# Создаем VLAN интерфейсы
ovs-vsctl add-port hq-sw vlan100 tag=100 -- set interface vlan100 type=internal
ovs-vsctl add-port hq-sw vlan200 tag=200 -- set interface vlan200 type=internal
ovs-vsctl add-port hq-sw vlan999 tag=999 -- set interface vlan999 type=internal

# 8. Обновляем конфигурацию сети с VLAN
echo "8. Обновление конфигурации сети..."
cat > /etc/network/interfaces << 'EOF'
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
address 172.16.1.2
netmask 255.255.255.240
gateway 172.16.1.1

auto vlan100
iface vlan100 inet static
address 192.168.100.1
netmask 255.255.255.224

auto vlan200
iface vlan200 inet static
address 192.168.100.33
netmask 255.255.255.240

auto vlan999
iface vlan999 inet static
address 192.168.100.49
netmask 255.255.255.248

post-up nft -f /etc/nftables.conf
post-up ip link set hq-sw up
EOF

# 9. Настройка GRE туннеля
echo "9. Настройка GRE туннеля..."
apt install -y network-manager

cat > /etc/network/interfaces.d/gre << 'EOF'
auto gre0
iface gre0 inet static
address 10.10.0.1
netmask 255.255.255.252
pre-up ip tunnel add gre0 mode gre local 172.16.1.2 remote 172.16.2.2 ttl 64
post-up ip link set gre0 up
EOF

# 10. Установка и настройка FRR (OSPF)
echo "10. Установка FRR для OSPF..."
apt install -y frr

# Включаем OSPF демон
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons

# Настраиваем FRR
cat > /etc/frr/frr.conf << 'EOF'
frr version 8.5.2
frr defaults traditional
hostname hq-rtr.au-team.irpo
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
router ospf
 router-id 1.1.1.1
 network 192.168.100.0/27 area 0
 network 192.168.100.32/28 area 0
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


# 12. Создание пользователя net_admin
echo "12. Создание пользователей..."
useradd -m -s /bin/bash net_admin -U
usermod -aG sudo net_admin
echo "net_admin:P@ssw0rd" | chpasswd

# Настройка sudo без пароля
echo "net_admin ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

# 13. Настройка часового пояса
echo "13. Настройка часового пояса..."
timedatectl set-timezone Asia/Krasnoyarsk

# 15. Создание скрипта проверки
cat > /usr/local/bin/check-hq-rtr << 'EOF'
#!/bin/bash
echo "=== Статус HQ-RTR ==="
echo "1. Интерфейсы:"
ip -br a
echo -e "\n2. VLAN:"
ovs-vsctl show
echo -e "\n3. Маршруты:"
ip route
echo -e "\n4. OSPF соседи:"
vtysh -c "show ip ospf neighbor" 2>/dev/null || echo "FRR не запущен"
echo -e "\n5. DHCP аренды:"
journalctl -u isc-dhcp-server -n 20 --no-pager
echo -e "\n6. Ping тесты:"
for ip in 172.16.1.1 192.168.100.2 192.168.100.34 10.10.0.2; do
    echo -n "Ping $ip: "
    ping -c 1 -W 1 $ip >/dev/null 2>&1 && echo "OK" || echo "FAIL"
done
EOF

chmod +x /usr/local/bin/check-hq-rtr

echo "========================================"
echo "Настройка HQ-RTR завершена!"
echo "========================================"
echo "Используйте: check-hq-rtr для проверки"
