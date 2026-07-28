#!/bin/bash

# Before run this script you must install dnsmasq and apache2

RootTFTP="/srv/tftp"
RootApache="/srv/http"
DirImages="images"
DirKs="kickstart"

DnsmasqConfFile="/etc/dnsmasq.d/pxe.conf"
ApacheConfFile="/etc/apache2/sites-available/pxe-server.conf"
PXEConfFile="$RootTFTP/grub/grub.cfg"

# https://releases.ubuntu.com/noble/ubuntu-24.04.4-live-server-amd64.iso
# https://releases.ubuntu.com/noble/ubuntu-24.04.4-netboot-amd64.tar.gz

UbuntuRepo='https://releases.ubuntu.com/noble'
UbuntuNetBootFile='ubuntu-24.04.4-netboot-amd64.tar.gz'
UbuntuISOFile='ubuntu-24.04.4-live-server-amd64.iso'
UbuntuKernal='vmlinuz'
UbuntuInitrd='initrd'

# Prepate files and directories for PXE server
##############################################

if [ ! -d "$RootApache/$DirImages" ]; then
        mkdir -p "$RootApache/$DirImages"
	echo "Make dir for ISO files: $DirImages"
fi

if [ ! -f "$RootApache/$DirImages/$UbuntuISOFile" ]; then
	echo "Downloading ISO: $UbuntuISOFile"
	wget -P "$RootApache/$DirImages" "$UbuntuRepo/$UbuntuISOFile"

	if [ $? -ne 0 ]; then
		echo "Error: Can't download ISO"
		exit 2
	fi
else
	echo "ISO $UbuntuISOFile was already downloaded"
fi

if [ ! -d "$RootTFTP" ]; then
        mkdir -p "$RootTFTP"
	echo "Make TFTF root dir: $RootTFTP"
fi

if [ ! -f "$RootTFTP/$UbuntuNetBootFile" ]; then
	echo "Downloading ubuntu netboot files ..."
	wget -P "$RootTFTP" "$UbuntuRepo/$UbuntuNetBootFile"

	if [ $? -eq 0 ]; then
		tar -xzvf "$RootTFTP/$UbuntuNetBootFile" -C "$RootTFTP"
		sleep 1
		mv "$RootTFTP"/amd64/* "$RootTFTP"
		rm -rf "$RootTFTP/amd64"
		rm -f "$RootTFTP/$UbuntuInitrd"
	else
		echo "Error: Can't download ubuntu netboot files"
		exit 1
	fi
else
	echo "File $UbuntuNetBootFile was already downloaded"
fi

mount -o loop "$RootApache/$DirImages/$UbuntuISOFile" /mnt
if [ ! -f "$RootTFTP/$UbuntuKernal" ]; then
	cp "/mnt/casper/$UbuntuKernal" "$RootTFTP"
else
	echo "File: "$UbuntuKernal" is already exist"
fi
if [ ! -f "$RootTFTP/$UbuntuInitrd" ]; then
	cp "/mnt/casper/$UbuntuInitrd" "$RootTFTP"
else
	echo "File: "$UbuntuInitrd" is already exist"
fi
umount /mnt

if [ ! -d "$RootApache/$DirKs" ]; then
        mkdir -p "$RootApache/$DirKs"
	echo "Make dir for Kickstart files: $RootApache/$DirKs/$DirKs"
fi

touch "$RootApache/$DirKs/meta-data"

# Confirating dnsmasq (DHCP and TFTP servers)
##############################################

echo "Update config: $DnsmasqConfFile"
cat <<EOF > "$DnsmasqConfFile"
# PXE server
interface=eth1
bind-interfaces

dhcp-range=eth1,192.168.60.200,192.168.60.230

dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-match=set:efi-x86_64,option:client-arch,9
dhcp-boot=tag:efi-x86_64,bootx64.efi

enable-tftp
tftp-root=$RootTFTP
EOF

# Confirating apache2
##############################################

echo "Update config: user-data"
cat <<'EOF' > "$RootApache/$DirKs/user-data"
#cloud-config
autoinstall:
  version: 1
 
  refresh-installer:
    update: false
  package_update: false
  package_upgrade: false

  locale: en_US.UTF-8
  keyboard:
    layout: us

  network:
    ethernets:
      enp0s3:
        dhcp4: true
      enp0s8:
        dhcp4: true
    version: 2

  source:
    id: ubuntu-server
    search_drivers: false
  ssh:
    allow-pw: true
    authorized-keys: []
    install-server: true

  identity:
    hostname: server
    password: $6$4WS/VCOXKN7v3WTN$1MiFlGrEt4EjrFfP31WmhIYjN9.9zSDAxZJCebuBBmqURlLhCYOi0I0t4O1Y6ZDltnpAVCl6pObqZGlwQ7AZQ1
    realname: megauser
    username: poweruser

  storage:
    layout:
      name: direct
EOF

echo "Update config: $ApacheConfFile"
cat <<EOF > "$ApacheConfFile"
# -PXE-HTTP server
<VirtualHost 192.168.60.150:80>
	DocumentRoot $RootApache
	<Directory $RootApache>
		Options Indexes MultiViews
		AllowOverride All
		Require all granted
	</Directory>

	ErrorLog /var/log/apache2/pxe-error.log
        CustomLog /var/log/apache2/pxe-access.log combined
</VirtualHost>
EOF

# Confirating PXE
##############################################
echo "Update config: $PXEConfFile"
cat <<EOF > "$PXEConfFile"
set default="0"
set timeout=3

menuentry "Install Ubuntu Server" {
	set default="0"
	set timeout=3

        set gfxpayload=keep

	echo "Loading kernel..."
#        linux   $UbuntuKernal iso-url=http://192.168.60.150/$DirImages/$UbuntuISOFile ip=dhcp cloud-init=disabled ---
        linux  $UbuntuKernal  iso-url=http://192.168.60.150/$DirImages/$UbuntuISOFile ip=dhcp autoinstall "ds=nocloud-net;s=http://192.168.60.150/$DirKs/"

	echo "Loading ramdisk..."
        initrd  $UbuntuInitrd
}
EOF

# Apply configurations and reload services
##############################################

systemctl restart dnsmasq

a2dissite 000-default.conf
a2dissite default-ssl.conf
a2ensite "$(basename $ApacheConfFile)"
systemctl reload apache2



