#!/bin/bash
# Полная настройка HQ-SRV для демонстрационного экзамена 2026
# Debian 13

set -e

echo "========================================"
echo "Настройка HQ-SRV (Debian 13)"
echo "========================================"

# 1. Настройка репозиториев
echo "1. Настройка репозиториев..."
sed -i '1s/^/#/' /etc/apt/sources.list
apt update
apt upgrade -y

# 2. Настройка имени хоста
echo "2. Настройка имени хоста..."
hostnamectl set-hostname hq-srv.au-team.irpo

# 3. Настройка сети
echo "3. Настройка сети..."
cat > /etc/network/interfaces << 'EOF'
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
address 192.168.100.2
netmask 255.255.255.224
gateway 192.168.100.1
EOF

# 4. Создание пользователя shuser
echo "4. Создание пользователей..."
useradd -m -s /bin/bash shuser -u 2026 -U
usermod -aG sudo shuser
echo "shuser:P@ssw0rd" | chpasswd

# Настройка sudo без пароля
echo "shuser ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

# 5. Настройка SSH
echo "5. Настройка SSH..."
apt install -y openssh-server

# Создаем баннер
cat > /etc/ssh_banner << 'EOF'
*******************************************************
*                                                     *
*                 Authorized access only              *
*                                                     *
*******************************************************
EOF

# Настраиваем SSH
cat > /etc/ssh/sshd_config.d/custom.conf << 'EOF'
Port 2026
AllowUsers shuser
MaxAuthTries 2
Banner /etc/ssh_banner
PasswordAuthentication yes
PermitRootLogin no
EOF

# 6. Установка и настройка BIND9 (DNS)
echo "6. Установка DNS сервера..."
apt install -y bind9 bind9-utils

# Создаем директории
mkdir -p /etc/bind/zones
mkdir -p /var/cache/bind/master

# Настраиваем options
cat > /etc/bind/named.conf.options << 'EOF'
options {
    directory "/var/cache/bind";
    allow-query { any; };
    forwarders {
        8.8.8.8;
    };
    dnssec-validation no;
    listen-on-v6 port 53 { none; };
    listen-on port 53 { 127.0.0.1; 192.168.100.0/27; 192.168.100.32/28; 192.168.200.0/28; };
};
EOF

# Настраиваем локальные зоны
cat > /etc/bind/named.conf.local << 'EOF'
zone "au-team.irpo" {
    type master;
    file "/var/cache/bind/master/au-team.db";
};

zone "100.168.192.in-addr.arpa" {
    type master;
    file "/var/cache/bind/master/au-team_rev.db";
};
EOF

# Создаем прямую зону
cat > /var/cache/bind/master/au-team.db << 'EOF'
$TTL 604800
@   IN  SOA localhost. root.localhost. (
    2          ; Serial
    604800     ; Refresh
    86400      ; Retry
    2419200    ; Expire
    604800 )   ; Negative Cache TTL

@   IN  NS  au-team.irpo.
@   IN  A   192.168.100.2

hq-rtr   IN  A   192.168.100.1
br-rtr   IN  A   192.168.200.1
hq-srv   IN  A   192.168.100.2
hq-cli   IN  A   192.168.100.35
br-srv   IN  A   192.168.200.2
moodle   IN  CNAME hq-rtr.au-team.irpo.
wiki     IN  CNAME hq-rtr.au-team.irpo.
EOF

# Создаем обратную зону
cat > /var/cache/bind/master/au-team_rev.db << 'EOF'
$TTL 604800
@   IN  SOA localhost. root.localhost. (
    1          ; Serial
    604800     ; Refresh
    86400      ; Retry
    2419200    ; Expire
    604800 )   ; Negative Cache TTL

@   IN  NS  au-team.irpo.
1   IN  PTR hq-rtr.au-team.irpo.
2   IN  PTR hq-srv.au-team.irpo.
35  IN  PTR hq-cli.au-team.irpo.
EOF

# Настраиваем права
chown -R bind:bind /var/cache/bind
chmod 644 /var/cache/bind/master/*

# 7. Настройка resolv.conf
echo "nameserver 192.168.100.2" > /etc/resolv.conf
chattr +i /etc/resolv.conf  # Запрещаем изменение

# 8. Настройка часового пояса
echo "7. Настройка часового пояса..."
timedatectl set-timezone Asia/Krasnoyarsk

# 9. Перезапуск служб
echo "8. Перезапуск служб..."
systemctl restart networking
systemctl restart ssh
systemctl restart bind9

# 10. Создание скрипта проверки
cat > /usr/local/bin/check-hq-srv << 'EOF'
#!/bin/bash
echo "=== Статус HQ-SRV ==="
echo "1. Интерфейсы:"
ip -br a
echo -e "\n2. Пользователи:"
id shuser
echo -e "\n3. SSH порт:"
ss -tlnp | grep :2026
echo -e "\n4. DNS служба:"
systemctl status bind9 --no-pager
echo -e "\n5. DNS разрешение:"
for host in hq-srv hq-rtr br-srv au-team.irpo; do
    echo -n "$host: "
    host $host.au-team.irpo 2>/dev/null | grep address || echo "FAIL"
done
echo -e "\n6. Ping тесты:"
for ip in 192.168.100.1 192.168.100.34 192.168.200.2; do
    echo -n "Ping $ip: "
    ping -c 1 -W 1 $ip >/dev/null 2>&1 && echo "OK" || echo "FAIL"
done
EOF

chmod +x /usr/local/bin/check-hq-srv

echo "========================================"
echo "Настройка HQ-SRV завершена!"
echo "========================================"
echo "Используйте: check-hq-srv для проверки"