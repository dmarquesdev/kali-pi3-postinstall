#!/bin/bash

# Update apt
apt-get update

# Install text editor
apt-get vim

# Expand parition
resize2fs -p /dev/mmcblk0p2

# Enable Wired Connection
sed -i -e "s/managed=false/managed=true/g" /etc/NetworkManager/NetworkManager.conf
service network-manager restart

# Update distro
apt-get dist-upgrade -y
apt-get autoremove

# Install dev essentials
apt-get install -y build-essential python-dev python3-dev git

# Change Password
passwd

# Create new user
echo 'Choose a username'
read USER
adduser $USER
adduser $USER sudo

# Fix SSH Keys
apt-get install openssh-server
update-rc.d -f ssh remove
update-rc.d -f ssh defaults
mkdir /etc/ssh/insecure_kali_keys
mv /etc/ssh/ssh_host_* /etc/ssh/insecure_kali_keys/
dpkg-reconfigure openssh-server

# AutoLogin
sed -i -e "s/#autologin-user=$/autologin-user=$USER" /etc/lightdm/lightdm.conf
sed -i -e "s/#autologin-user-timeout=0$/autologin-user-timeout=0" /etc/lightdm/lightdm.conf

# Configure SSH Server
echo 'Pick a SSH port'
read SSH_PORT
sed -i -e "s/#Port 22/Port $SSH_PORT/g" /etc/ssh/sshd_config
sed -i -e 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
sed -i -e "s/#PubkeyAuthentication/PubkeyAuthentication/g" /etc/ssh/sshd_config
service ssh restart

# Install Kali Full
apt-get install kali-linux-full -y

# Install and Configure VNC
apt-get install -y autocutsel
vncserver :1
cp vncboot /etc/init.d/vncboot
chmod 755 /etc/init.d/vncboot
update-rc.d vncboot defaults

# Install hostapd and dnsmasq
apt-get install -y hostapd dnsmasq

# Configure private AP
echo "Enter the first 3 AP IP octets (i.e. 192.168.0)"
read OCTETS
echo "
auto wlan0
iface wlan0 inet static
hostapd /etc/hostapd/hostapd.conf
address $OCTETS.1
netmask 255.255.255.0
network $OCTETS.0
broadcast $OCTETS.255" >> /etc/network/interfaces
echo "denyinterfaces wlan0" >> /etc/dhcpd.conf

echo "Enter the AP ssid"
read SSID
echo "Enter the AP channel"
read CHANNEL
echo "Enter the AP WPA Password"
read WPA_PASS
echo "interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=$CHANNEL
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$WPA_PASS
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP" > /etc/hostapd/hostapd.conf

sed -i -e "s/#DAEMON_CONF=\"\"/DAEMON_CONF=\"\/etc\/hostapd\/hostapd.conf\"/g" /etc/default/hostapd

echo "interface=wlan0
listen-address=$OCTETS.1
bind-interfaces
server=8.8.8.8
domain-needed
bogus-priv
dhcp-range=$OCTETS.2,$OCTETS.10,12h" > /etc/dnsmasq.conf

sed -i -e "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" /etc/sysctl.conf
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE
iptables -A FORWARD -i wlan1 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o wlan1 -j ACCEPT

iptables-save > /etc/iptables.ipv4.nat

echo "pre-up iptables restore /etc/iptables.ipv4.nat" >> /etc/network/interfaces
