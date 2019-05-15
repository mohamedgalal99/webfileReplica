#!/bin/bash
source print.sh

script_path="$(pwd)"
keepalive_iface="enp0s8"
floating_ip="192.168.1.10/24"
keepalive_pass="lol1234"
keepalive_servers=(
192.168.1.2
192.168.1.3
)


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



print "info" "installing docker"
apt install -y docker.io

docker_path=$(which docker)
[[ -z "${docker_path}" ]] && { print "err" "docker command not found"; exit 1; }

if [[ -f "${script_path}/dock/Dockerfile" ]]
then
	print "info" "Going to build docker image for nginx, this gona take sometime :)"
	img_id=$(${docker_path} build ${script_path}/dock/ | grep "Successfully built" | awk '{print $NF}')
	[[ -z "${img_id}" ]] && { print "err" "Faild to build image"; exit 1; } || print "ok" "imge built ${img_id}"

	log_file="/var/log/nginx/"
	[[ -d "${log_file}" ]] && mkdir -p "${log_file}"
	root_dir="/srv/data"
	[[ -d "${root_dir}" ]] && mkdir -p "${root_dir}"

	docker run -d -p 80:80 -v "${script_path}"/nginx/sites-enabled:/etc/nginx/sites-enabled -v "${script_path}"nginx/sites-available:/etc/nginx/sites-available -v "${script_path}"/nginx/conf.d:/etc/nginx/conf.d -v "${log_file}":/var/log/nginx -v "${root_dir}":/var/www/html --name nginx-web ${img_id}

fi


print "info" "Installing nfs client"
apt install nfs-kernel-server

# keepalived
server_ip=$(ip -4 -o a s ${keepalive_iface} | head -1 | awk '{print $4}' | sed 's#/24##')
install_keepalived


print "info" "Creating docker Nginx HA scripts"
if [[ -d "/etc/keepalived/" ]]
then
	cp ${script_path}/docker.sh /etc/keepalived/
	cp ${script_path}/keepalivednotify_web.sh /etc/keepalived/
else
	print "err" "Can't find /etc/keepalived/ dir"
	exit 1
fi

print "info" "Creating keepalived config file"
cat << EOF > /etc/keepalived/keepalived.conf
vrrp_script chk_docker_nginx {
    script "/bin/bash /etc/keepalived/docker.sh"
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
    notify /etc/keepalived/keepalivednotify_web.sh
}
EOF

cp /tmp/keepalive/keepalived-2.0.16/keepalived/keepalived.service /lib/systemd/system
systemctl daemon-reload
systemctl enable keepalived.service
systemctl start keepalived
