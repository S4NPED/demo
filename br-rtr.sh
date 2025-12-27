apt remove git
rm -r /root/demo
cat > /etc/network/interfaces << 'EOF'
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
address 172.16.2.2/28
gateway 172.16.2.1

auto ens4
iface ens4 inet static
address 192.168.200.1/28

auto tun1
iface tun1 inet tunnel
address 10.10.0.2
netmask 255.255.255.252
mode gre
local 172.16.2.2
endpoint 172.16.1.2
ttl 64

post-up nft -f /etc/nftables.conf
post-up ip link set tun1 up
post-up ip link set gre0 up
EOF
echo > /etc/sysctl.d/sysctl.conf
sed -i '1i net.ipv4.ip_forward=1' /etc/sysctl.d/sysctl.conf
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
sed -i '51a net_admin ALL=(ALL:ALL) NOPASSWD:ALL' /etc/sudoers
apt install -y frr
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
systemctl restart frr
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
 ospf router-id 2.2.2.2
 network 192.168.200.0/28 area 0
 network 10.10.0.0/30 area 0
 area 0 authentication
 passive-interface default
 no passive-interface tun1
!
line vty
!
EOF

rm /root/.bash_history
history -c
nano /etc/apt/sources.list
hostnamectl set-hostname br-rtr.au-team.irpo
nano /etc/network/interfaces
nano /etc/sysctl.d/sysctl.conf
nano /etc/nftables.conf
useradd -m -s /bin/bash net_admin -U
usermod -aG sudo net_admin
passwd net_admin
P@ssw0rd
P@ssw0rd
nano /etc/sudoers
apt install -y frr
nano /etc/frr/daemons
systemctl restart frr
nano /etc/frr/frr.conf
timedatectl set-timezone Asia/Krasnoyarsk
