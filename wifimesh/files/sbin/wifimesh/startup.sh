#!/bin/sh /etc/rc.common
# Copyright © 2011-2013 WiFi Mesh: New Zealand Ltd.
# All rights reserved.

START=98
STOP=15

boot() {
# Fix the permissions
chmod 0777 /etc/init.d/chilli > /dev/null
chmod 0777 /etc/init.d/wifimesh > /dev/null
chmod 0777 /sbin/wifimesh/*.sh > /dev/null
chmod 0777 /www/cgi-bin/*.cgi > /dev/null

# Start wifimesh at boot
/etc/init.d/wifimesh enable

# Load in the settings
. /sbin/wifimesh/settings.sh

# Add a new line to the log file signalling a reboot
log_message

# set the default type
type=0

# If the first_file exists, configure the node
if [ -e "/sbin/wifimesh/first_boot" ]; then
log_message "first_boot: Starting..."

log_message "first_boot: configuring the firewall"
uci set firewall.@zone[1].input="ACCEPT"
uci commit firewall
/etc/init.d/firewall restart

log_message "first_boot: disable dnsmasq"
/etc/init.d/dnsmasq disable
/etc/init.d/dnsmasq stop

log_message "first_boot: configuring the bridges"
brctl addbr br-wan
brctl addbr br-lan

log_message "first_boot: configuring the network"
uci set network.wan="interface"
uci set network.wan.type="bridge"
uci set network.wan.ifname="eth0"
uci set network.wan.proto="dhcp"
uci set network.lan.ifname=""
uci set network.lan.ipaddr="${ip_lan}"
if [ "$(ifconfig -a | grep 'eth1' | awk '{ print $1 }')" == "eth1" ]; then # Adds support for multiple physical adapters, flips the adapters if listed
	uci set network.lan.ifname="eth1"
	if [ -n "$(grep -F $(cat /proc/cpuinfo | grep 'machine' | cut -f2 -d ":" | cut -b 2-50 | awk '{ print $2 }') "/sbin/wifimesh/flipETH.list")" ]; then
		uci set network.lan.ifname="eth0"
		uci set network.wan.ifname="eth1"
	fi
fi
uci commit network

# Enable the wifi radios
log_message "first_boot: configuring the wifi"
uci set wireless.${radio_mesh}.disabled="0"
uci set wireless.${radio_client}.disabled="0"
uci set wireless.${radio_mesh}.distance="2000"
uci set wireless.${radio_client}.distance="2000"
uci set wireless.${radio_mesh}.country="US"
uci set wireless.${radio_client}.country="US"

# Create the SSID #1/Public wifi interface (if it doesn't already exist)
if [ -z "$(uci get wireless.@wifi-iface[1])" ]; then uci add wireless wifi-iface; fi

# Set the defaults on those interfaces
uci set wireless.@wifi-iface[0].device="radio0"
uci set wireless.@wifi-iface[0].network="wan"
uci set wireless.@wifi-iface[0].mode="mesh"
uci set wireless.@wifi-iface[0].mesh_id="wifimesh"
uci set wireless.@wifi-iface[0].encryption="none"

uci set wireless.@wifi-iface[1].device="radio0"
uci set wireless.@wifi-iface[1].network="lan"
uci set wireless.@wifi-iface[1].mode="ap"
uci set wireless.@wifi-iface[1].ssid="${ssid}"
uci set wireless.@wifi-iface[1].encryption="none"
uci set wireless.@wifi-iface[1].key=""
uci set wireless.@wifi-iface[1].hidden="0"
uci commit wireless
/etc/init.d/network restart

log_message "first_boot: setting the ssh default key"
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDuLKVreW2p8il5V4C/nolnyEcD8GtNoC0N6Ynu3d3QGFukY05Z0iax3MQkHHII6itosRWLlWVhFNI3ThYxS+wH3VORYIgkisZwx+6/Kgjyb37ViwPfwFqgpFUFnGw5TaVM1pQnH1mp7eFzhd/bKw5vsez1zD8aZuaI4Bw+Nzi3G/9ZtWc/BIQh2SXeIhdcHiqIF8mJx8Up9XGq/GPNI3XoR5bW7gFpMJFPbMU4WgntJh0UkDGeDwnYoIBkjfLmdaXI9V8YW1+DVDiq2pHJD049Mn+CRRnkyOfKeWLioKFIkF87os5D2dEuMSodeRMYtCPVU6ZjTA3xOs1jA94coclP codycooper@codys-mac.local" > /etc/dropbear/authorized_keys

log_message "first_boot: setting the ssh default password"
echo -e "w1f1m35h\nw1f1m35h" | passwd root

log_message "first_boot: configuring uhttpd"
uci set uhttpd.main.realm="my.wifi-mesh.co.nz"
uci set uhttpd.px5g.commonname="my.wifi-mesh.co.nz"
uci set uhttpd.px5g.country="NZ"
uci set uhttpd.px5g.state="Auckland"
uci set uhttpd.px5g.location="Auckland"
uci commit uhttpd
/etc/init.d/uhttpd enable
/etc/init.d/uhttpd restart

log_message "first_boot: configuring coova-chilli"
echo "HS_LANIF='br-lan'
HS_WANIF='br-wan'
HS_NETWORK='$(echo $ip_lan | cut -d . -f 1-3).0'
HS_NETMASK='255.255.255.0'
HS_UAMLISTEN='${ip_lan}'
HS_NASMAC='$(ifconfig br-lan | grep 'HWaddr' | awk '{ print $5 }' | sed 's/:/-/g')'
HS_NASIP='${ip_lan}'
HS_UAMPORT='3990'
HS_UAMUIPORT='4990'
HS_DNS1='8.8.8.8'
HS_DNS2='8.8.4.4'
HS_NASID='000'
HS_RADIUS='localhost'
HS_RADIUS2='localhost'
HS_RADSECRET='secret'
HS_UAMSECRET='secret'
HS_UAMALIASNAME='chilli'
HS_AAA='http'
HS_UAMAAAURL='http://localhost/aaa.txt'
HS_UAMSERVER='${ip_lan}'
HS_UAMFORMAT='http://${ip_lan}/first_boot.html'
HS_UAMHOMEPAGE='http://${ip_lan}:3990/www/coova.html'
HS_TCP_PORTS='22 23 80 443'
HS_MODE='hotspot'
HS_TYPE='chillispot'
HS_WWWDIR='/etc/chilli/www'
HS_WWWBIN='/etc/chilli/wwwsh'
HS_RAD_PROTO='chap'" > /etc/chilli/defaults
/etc/init.d/chilli enable
/etc/init.d/chilli start

log_message "first_boot: configuring the VPN"
uci delete openvpn.custom_config
uci delete openvpn.sample_server
uci commit openvpn
/etc/init.d/openvpn enable

log_message "first_boot: enabling cron at boot"
crontab /sbin/wifimesh/cron.txt
/etc/init.d/cron enable

# Move the firmware default coova.html file into the actual directory, if necessary
if [ -e "/sbin/wifimesh/coova.html" ]; then mv /sbin/wifimesh/coova.html /etc/chilli/www/coova.html; fi

log_message "first_boot: saving ssh banner"
cat > /etc/banner << banner_end
  ________ __ _______ __   _______               __     
  |  |  |  |__|    ___|__| |   |   |.-----.-----.|  |--.
  |  |  |  |  |    ___|  | |       ||  -__|__ --||     |
  |________|__|___|   |__| |__|_|__||_____|_____||__|__|

  v${package_version}       (c) 2011-2013 WiFi Mesh: New Zealand Ltd.
  ------------------------------------------------------
  Powered by:	
  http://www.wifi-mesh.co.nz     http://www.openwrt.org
  http://coova.org               http://www.wifirush.com
  ------------------------------------------------------
banner_end

log_message "first_boot: removing first_boot marker file"
rm /sbin/wifimesh/first_boot

log_message "first_boot: done, rebooting..."
sleep 10
reboot

# mark it as a new boot
type=1
fi

log_message "boot: enable stp on the wan bridge"
sleep 1 && brctl stp br-wan on

log_message "boot: loading in cronjobs"
crontab /sbin/wifimesh/cron.txt
}

start() {
boot
}

stop() {
echo "nothing happens"
}
