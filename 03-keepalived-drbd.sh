#!/bin/bash
source print.sh

keepalive_iface="enp0s8"
floating_ip="192.168.1.10/24"
keepalive_servers=(
192.168.1.2
192.168.1.3
)

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
	./configure
	make
	make install
	print "ok" "Keepalived installed" "1"
}

# Collecting info from server && build keppalive config
server_ip=$(ip -4 -o a s ${keepalive_iface} | head -1 | awk '{print $4}' | sed 's#/24##')
install_keepalive

print "info" "Creating drbd HA scripts"
cp ${script_path}/drbd_ha.sh /etc/keepalived
cp ${script_path}/keepalivednotify.sh /etc/keepalived
print "info" "Creating keepalived config file"
cat << EOF > as
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

systemctl enable keepalived
systemctl start keepalived
