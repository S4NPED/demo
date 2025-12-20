#!/bin/bash
# Полная настройка ISP для демонстрационного экзамена 2026
# Специальность 09.02.06 Сетевое и системное администрирование
# Debian 13

set -e  # Прерывать выполнение при ошибках

echo "========================================"
echo "Настройка ISP (Debian 13)"
echo "========================================"

# 1. Настройка репозиториев
echo "1. Настройка репозиториев..."
sed -i '1s/^/#/' /etc/apt/sources.list  # Комментируем строку с cdrom
echo "Репозитории настроены"

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
echo "5. Включение IP forwarding..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/sysctl.conf
sysctl --system

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

# 7. Перезапуск сетевых служб
echo "7. Перезапуск сетевых служб..."
systemctl restart NetworkManager
systemctl restart networking

# 8. Установка необходимых утилит
echo "8. Установка утилит..."
apt install -y \
    iproute2 \
    net-tools \
    curl \
    wget \
    dnsutils \
    tcpdump

# 9. Настройка SSH (базовая)
echo "9. Настройка SSH..."
apt install -y openssh-server
systemctl enable ssh
systemctl start ssh

# 10. Настройка часового пояса (Красноярск)
echo "10. Настройка часового пояса..."
timedatectl set-timezone Asia/Krasnoyarsk

# 11. Установка NTP
echo "11. Настройка времени..."
apt install -y systemd-timesyncd
systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd

# 12. Создание тестового файла для проверки
echo "12. Создание файла проверки..."
cat > /root/isp_setup_check.txt << 'EOF'
Проверка настройки ISP:
1. Репозитории настроены ✓
2. Имя хоста: isp.au-team.irpo
3. Сеть настроена:
   - ens3: DHCP (внешний интерфейс)
   - ens4: 172.16.1.1/28 (к HQ-RTR)
   - ens5: 172.16.2.1/28 (к BR-RTR)
4. IP forwarding включен ✓
5. NAT настроен через nftables ✓
6. Часовой пояс: Asia/Krasnoyarsk ✓
EOF

# 13. Проверка конфигурации
echo "13. Проверка конфигурации..."
echo "Проверка имени хоста:"
hostnamectl

echo -e "\nПроверка IP-адресов:"
ip -br a

echo -e "\nПроверка маршрутов:"
ip route

echo -e "\nПроверка forwarding:"
sysctl net.ipv4.ip_forward

echo -e "\nПроверка часового пояса:"
timedatectl

# 14. Создание скрипта проверки
cat > /usr/local/bin/check-isp-status << 'EOF'
#!/bin/bash
echo "=== Статус ISP ==="
echo "1. Интерфейсы:"
ip -br a
echo -e "\n2. Маршруты:"
ip route
echo -e "\n3. NAT правила:"
nft list ruleset
echo -e "\n4. Время:"
timedatectl
echo -e "\n5. Ping тесты:"
echo "Тест HQ-RTR:"
ping -c 2 172.16.1.2 2>/dev/null || echo "Недоступен"
echo -e "\nТест BR-RTR:"
ping -c 2 172.16.2.2 2>/dev/null || echo "Недоступен"
EOF

chmod +x /usr/local/bin/check-isp-status

# 15. Настройка firewall (дополнительная безопасность)
echo "14. Настройка базового firewall..."
cat > /etc/nftables-security.conf << 'EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet firewall {
    chain input {
        type filter hook input priority filter; policy drop;
        
        # Разрешаем established/related соединения
        ct state established,related accept
        
        # Разрешаем loopback
        iifname "lo" accept
        
        # Разрешаем ICMP
        ip protocol icmp accept
        
        # Разрешаем SSH (стандартный порт)
        tcp dport 22 accept
        
        # Разрешаем входящие пакеты от внутренних сетей
        ip saddr { 172.16.1.0/28, 172.16.2.0/28, 192.168.100.0/27, 192.168.100.32/28, 192.168.200.0/28 } accept
    }
    
    chain forward {
        type filter hook forward priority filter; policy accept;
        
        # Разрешаем forwarding между сетями
        ct state established,related accept
        
        # Разрешаем forwarding от внутренних сетей
        ip saddr { 172.16.1.0/28, 172.16.2.0/28 } accept
    }
    
    chain output {
        type filter hook output priority filter; policy accept;
    }
}
EOF

echo "========================================"
echo "Настройка ISP завершена!"
echo "========================================"
echo "Для проверки используйте команды:"
echo "1. check-isp-status  - полная проверка"
echo "2. ip -br a          - список интерфейсов"
echo "3. ip route          - таблица маршрутизации"
echo "4. nft list ruleset  - правила nftables"
echo "========================================"
echo "Не забудьте перезагрузить устройство для"
echo "применения всех изменений: reboot"
echo "========================================"