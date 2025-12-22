#!/bin/bash
# Полная настройка HQ-RTR для демонстрационного экзамена 2026
# Debian 13

echo "========================================"
echo "Настройка HQ-RTR (Debian 13)"
echo "========================================"

apt update

# 2. Настройка имени хоста
echo "2. Настройка имени хоста..."
hostnamectl set-hostname hq-rtr.au-team.irpo

# 9. Настройка GRE туннеля
echo "9. Настройка GRE туннеля..."
apt install -y network-manager

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

auto tun1
iface tun1 inet tunnel
address 10.10.0.1
netmask 255.255.255.252
mode gre
local 172.16.1.2
endpoint 172.16.2.2
ttl 64

post-up nft -f /etc/nftables.conf
post-up ip link set hq-sw up
post-up ip link set tun1 up
post-up ip link set gre0 up
EOF

# 4. Включение IP forwarding
echo > /etc/sysctl.d/sysctl.conf
sed -i '1i net.ipv4.ip_forward=1' /etc/sysctl.d/sysctl.conf

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

# 12. Создание пользователя net_admin
echo "12. Создание пользователей..."
useradd -m -s /bin/bash net_admin -U
usermod -aG sudo net_admin
echo "net_admin:P@ssw0rd" | chpasswd

# Настройка sudo без пароля
sed -i '51a net_admin ALL=(ALL:ALL) NOPASSWD:ALL' /etc/sudoers

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

# 10. Установка и настройка FRR (OSPF)
echo "10. Установка FRR для OSPF..."
apt install -y frr

# Включаем OSPF демон
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons

# 3. Перезапуск FRR
echo "Перезапускаем FRR..."
systemctl restart frr

# Создаем конфигурацию OSPF
cat > /etc/frr/frr.conf << 'EOF'
frr version 10.3
frr defaults traditional
hostname router
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
interface tun1
 ip ospf authentication
 ip ospf authentication-key password
 ip ospf network point-to-point
 no ip ospf passive
!
router ospf
 ospf router-id 1.1.1.1
 network 192.168.100.0/27 area 0
 network 192.168.100.32/28 area 0
 network 10.10.0.0/30 area 0
 area 0 authentication
 passive-interface default
 no passive-interface tun1
!
line vty
!
EOF

# 11. Установка и настройка DHCP сервера
echo "11. Установка DHCP сервера..."
apt install -y isc-dhcp-server

# Настраиваем интерфейс для DHCP
cat > /etc/default/isc-dhcp-server << 'EOF'
INTERFACESv4="vlan200"
INTERFACESv6=""
EOF

# Настраиваем DHCP
cat > /etc/dhcp/dhcpd.conf << 'EOF'
option domain-name "au-team.irpo";
option domain-name-servers 192.168.100.2;

default-lease-time 600;
max-lease-time 7200;

ddns-update-style none;

authoritative;

subnet 192.168.100.32 netmask 255.255.255.240 {
    range 192.168.100.34 192.168.100.47;
    option routers 192.168.100.33;
}
EOF

# 13. Настройка часового пояса
echo "13. Настройка часового пояса..."
timedatectl set-timezone Asia/Krasnoyarsk

echo "========================================"
echo "Настройка HQ-RTR завершена!"
echo "========================================"
rm -r /root/demo
