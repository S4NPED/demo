#!/bin/bash
# Полная настройка BR-SRV для демонстрационного экзамена 2026
# Debian 13

echo "========================================"
echo "Настройка BR-SRV (Debian 13)"
echo "========================================"

apt update

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
useradd -m -s /bin/bash sshuser -u 2026 -U
usermod -aG sudo sshuser
echo "sshuser:P@ssw0rd" | chpasswd

# Настройка sudo без пароля
sed -i '51a sshuser ALL=(ALL:ALL) NOPASSWD:ALL' /etc/sudoers

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
cat > /etc/ssh/sshd_config << 'EOF'
Port 2026
AllowUsers sshuser
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

# 7. Настройка часового пояса
echo "7. Настройка часового пояса..."
timedatectl set-timezone Asia/Krasnoyarsk

echo "========================================"
echo "Настройка BR-SRV завершена!"
echo "========================================"
rm -r /root/demo
