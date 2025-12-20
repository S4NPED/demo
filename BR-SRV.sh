#!/bin/bash
# Полная настройка BR-SRV для демонстрационного экзамена 2026
# Debian 13

set -e

echo "========================================"
echo "Настройка BR-SRV (Debian 13)"
echo "========================================"

apt update
apt upgrade -y

# 2. Настройка имени хоста
echo "2. Настройка имени хоста..."
hostnamectl set-hostname br-srv.au-team.irpo

# 3. Настройка сети
echo "3. Настройка сети..."
cat > /etc/network/interfaces << 'EOF'
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
address 192.168.200.2
netmask 255.255.255.240
gateway 192.168.200.1
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

# 6. Настройка DNS
echo "6. Настройка DNS..."
cat > /etc/resolv.conf << 'EOF'
nameserver 192.168.100.2
search au-team.irpo
EOF
chattr +i /etc/resolv.conf

# 7. Настройка часового пояса
echo "7. Настройка часового пояса..."
timedatectl set-timezone Asia/Krasnoyarsk

# 9. Создание скрипта проверки
cat > /usr/local/bin/check-br-srv << 'EOF'
#!/bin/bash
echo "=== Статус BR-SRV ==="
echo "1. Интерфейсы:"
ip -br a
echo -e "\n2. Пользователи:"
id shuser
echo -e "\n3. SSH порт:"
ss -tlnp | grep :2026
echo -e "\n4. DNS:"
cat /etc/resolv.conf
echo -e "\n5. Ping тесты:"
for ip in 192.168.200.1 192.168.100.2 192.168.100.34; do
    echo -n "Ping $ip: "
    ping -c 1 -W 1 $ip >/dev/null 2>&1 && echo "OK" || echo "FAIL"
done
echo -e "\n6. DNS проверка:"
for host in br-srv hq-srv au-team.irpo; do
    echo -n "$host: "
    host $host.au-team.irpo 2>/dev/null | grep address || echo "FAIL"
done
echo -e "\n7. SSH тест к HQ-SRV:"
timeout 2 ssh -o ConnectTimeout=1 -p 2026 shuser@192.168.100.2 "echo SSH доступен" 2>/dev/null && echo "SSH: OK" || echo "SSH: FAIL"
EOF

chmod +x /usr/local/bin/check-br-srv

echo "========================================"
echo "Настройка BR-SRV завершена!"
echo "========================================"
echo "Используйте: check-br-srv для проверки"
