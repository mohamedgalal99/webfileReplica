#!/bin/bash
# Title          :03-keepalived-drbd.sh
# Description    :Installing NFS server and keepalived for DRBD
# Author         :Mohamed Galal
# Example        :# bash 03-keepalived-drbd.sh
source print.sh

# Script Variables needed, easy to link later 
keepalive_iface="enp0s8"
floating_ip="192.168.1.10/24"
keepalive_servers=(
192.168.1.2
192.168.1.3
)
drbd_new=(
"/dev/drbd0"
"/dev/drbd1"
)
mount_point=(
"/srv/data"
"/srv/web"
)
nfs_file="/etc/exports"
###############################################

for i in  ${keepalive_servers[@]}
do
	echo ${i}
done
keepalive_pass="qwerty1234"
script_path=$(pwd)

function install_keepalive () 
{
	print "info" "Start installing Keepalived" "1"
	mkdir /tmp/keepalive
	cd /tmp/keepalive
	print "info" "Downloading Keepalived 2.0.16 source" "1"
	wget https://www.keepalived.org/software/keepalived-2.0.16.tar.gz || { print "err" "Can't install keepalived please check your connection or url :P " "1"; exit 1; }
	tar xzvf keepalived-2.0.16.tar.gz
	cd keepalived-2.0.16
	./configure || { print "err" "Can't install keepalived , plz check"; exit 1; }
	make
	make install
	mkdir /etc/keepalived/
	print "ok" "Keepalived installed" "1"
}

function install_nfs_server ()
{
	ip="${1:-127.0.0.1}"
	apt install -y nfs-kernel-server
	ip_mask="$(ip a s | grep "${ip}" | awk '{print $2}')"
	network="$(ipcalc ${ip_mask} | grep -Ei "^network" | awk '{print $2}')"
	cat << EOF >> ${nfs_file}
$( for (( i = 0; i < ${#mount_point[@]}; i++ ))
do
line="${mount_point[${i}]} ${network}(rw,async,no_root_squash,no_subtree_check,fsid=$((( ${i} + 1 ))))"
[[ ! $(grep -E "^${mount_point[${i}]} ${network}" ${nfs_file}) ]] && echo "${line}" >> ${nfs_file}
done
)
EOF
}

# Collecting info from server && build keppalive config
server_ip=$(ip -4 -o a s ${keepalive_iface} | head -1 | awk '{print $4}' | sed 's#/24##')

install_nfs_server "${server_ip}"
install_keepalive

print "info" "Creating drbd HA scripts"
if [[ -d "/etc/keepalived/" ]]
then
	cp ${script_path}/drbd_ha.sh /etc/keepalived/
	cp ${script_path}/keepalivednotify.sh /etc/keepalived/
else
	print "err" "CAn't find /etc/keepalived/ dir"
	exit 1
fi

print "info" "Creating keepalived config file"
cat << EOF > /etc/keepalived/keepalived.conf
vrrp_script chk_drbd {
    script "/bin/bash /etc/keepalived/drbd_ha.sh"
    interval 3
    weight -4
    fall 1
    rise 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface ${keepalive_iface}
    virtual_router_id 60
    priority 100
    advert_int 5
    authentication {
        auth_type AH
        auth_pass ${keepalive_pass}
    }
    unicast_src_ip ${server_ip}
    unicast_peer {
        $( for i in  ${keepalive_servers[@]}
           do
               [[ "${i}" != "${server_ip}" ]] && echo -e "${i}"
           done
         )
    }
    virtual_ipaddress {
        ${floating_ip}
    }
    track_script {
        chk_drbd
    }
    notify /etc/keepalived/keepalivednotify.sh
}
EOF

cp /tmp/keepalive/keepalived-2.0.16/keepalived/keepalived.service /lib/systemd/system
systemctl daemon-reload
systemctl enable keepalived.service
systemctl start keepalived
