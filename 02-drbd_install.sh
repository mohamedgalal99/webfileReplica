#!/bin/bash
# Title          :02-drbd_install.s
# Description    :Install and configure DRBD and mount it on primary node
# Author         :Mohamed Galal
# Example        :# bash 02-drbd_install.sh ip1 ip2
# Note1		 : ip1 should be primary ip
# Note2		 : ssh key should be exchanged between all hosts even host it self
source print.sh

servers=($@)
r_name="r0"
script_dir="$(pwd)"
drbd_disks=(
"/dev/r0/files"
"/dev/r0/web"
)
drbd_new=(
"/dev/drbd0"
"/dev/drbd1"
)
mount_point=(
"/srv/data"
"/srv/web"
)


function send_ssh_command ()
{
	[[ ${#@} != 2 ]] && { echo "[-] send_ssh_command function take only two args"; exit 1; }
	ip=$1
	comma=$2
	ssh -A -q -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -o "ConnectTimeout=4" -o "PasswordAuthentication=no" -o "PubkeyAuthentication=yes" root@${ip} "${comma}"
}

function disable_service ()
{
	service=$1
	systemctl is-enabled ${service} && { systemctl disable ${service}; systemctl stop ${service}; }
}

function primary ()
{
	drbdadm create-md ${r_name} && print "ok" "drbd create-md" || { print "err" "drbd create-md"; exit 1; }
	drbdadm up ${r_name} && print "ok" "drbd is up and running" || { print "err" "drbd still down"; exit 1; }
	drbdadm primary --force ${r_name} && print "ok" "This node become primary" || { print "err" "faild to be primary"; exit 1; }
	for (( i =0; i < ${#drbd_new[@]}; i++ ))
	do
		mkfs.ext4 ${drbd_new[$i]}
		mount ${drbd_new[${i}]} ${mount_point[${i}]}
	done
	print "ok" "Hope everything is ok primay"

}
function secondary ()
{
	drbdadm create-md ${r_name} && print "ok" "drbd create-md" || { print "err" "drbd create-md"; exit 1; }
	drbdadm up ${r_name} || { print "err" "drbd still down"; exit 1; }
	print "ok" "hope u secondary join ur cluster"
}

[[ -n ${servers} ]] || { print "err" "plase provide set of ip address for drbd: \"ip1\" \"ip2\""; exit 1; }
[[ -n ${drbd_disks} ]] || { print "err" "plase provide disks, open script"; exit 1; }
[[ -n ${mount_point} ]] || { print "err" "plase provide set of ip address for drbd: ip1 ip2"; exit 1; }


print "info" "Going to install DRBD"
apt install -y make gcc linux-headers-$(uname -r) build-essential 
apt install -y make-guile psmisc bison flex libssl-dev ipcalc
apt install -y linux-modules-extra-$(uname -r) drbd-module-source  drbd-utils

# Postifix will be installed so I will bass it's interactive window
debconf-set-selections <<< "postfix postfix/mailname string ${hostname}.com"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'No Configuration'"


mkdir /tmp/drbd
cd /tmp/drbd
wget https://www.linbit.com/downloads/drbd/8.4/drbd-8.4.11-1.tar.gz || { print "err" "drbd kernel download link not found"; exit 1; }
tar xzvf drbd-8.4.11-1.tar.gz
cd drbd-8.4.11-1
make || { print "err" "compile drbd kernel module fail fix"; exit 1; }
make install && print "ok" "drbd kernel moudule installed succesfully"

modinfo drbd || { print "err" "Kernel module drbd not loaded fix by ur hand"; exit 1; }
print "info" "Disable postfix :D"
disable_service postfix

# checking that i connect to all other nodes and dump their hostname to my hosts if not there if ssh key not exchanged between ur hosts, and u did that manually hash this section and add arry of hosts

########################################
# Checking connectoin to other servers #
########################################
# ssh key should be exchanged between all hosts even host itself
print "info" "Checking connection to other node , hope u exchange key between them :)"
connection=0
for server_ip in ${servers[@]}
do
	server_name=$(send_ssh_command "${server_ip}" "hostname")
	if [[ -n "${server_name}" ]]
	then
		grep -E "${server_ip}\s${server_name}$|${server_ip}\s${server_name} " /etc/hosts &> /dev/null
		[[ $? != 0 ]] && echo -e "${server_ip}\t${server_name}" >> /etc/hosts
		print "ok" "Ping ${server_ip}"
	else
		print "err" "Can't connect to ${server_ip}, plz check if u add server pub key"
		connection=1
	fi
done
[[ ${connection} = 1 ]] && exit 1

################################
# Make drbd configuration file #
################################

drbd_dir="/etc/drbd.d"
[[ ! -d "${drbd_dir}" ]] && { mkdir ${drbd_dir} ; print "Creating drbd dir"; }

if [[ -f "${drbd_dir}/global_common.conf" ]]
then
	cp "${drbd_dir}/global_common.conf" "${drbd_dir}/global_common-$(date +%s).bkp"
fi

cat << EOF > "${drbd_dir}/global_common.conf"
global {
	usage-count no;
}
common {
	handlers {
	}
	startup {
	}
	options {
	}
	disk {
	}
	net {
                protocol C;
	}
}
EOF

hosts=()
for i in ${servers[@]}
do
	hosts=(${hosts[@]} "$(grep "${i}" /etc/hosts | awk '{print $NF}')")
done

cat << EOF > "${drbd_dir}/${r_name}.res"
resource ${r_name} {
$( 
for (( i = 0 ; i < ${#drbd_disks[@]} ; i++ ))
do
    echo -e "    volume ${i} {" 
    echo -e "        device\t${drbd_new[${i}]};"
    echo -e "        disk\t${drbd_disks[${i}]};"
    echo -e "        meta-disk\tinternal;\n    }"
    
done
)
$(
for (( i = 0 ; i < ${#hosts[@]} ; i++ ))
do
    echo -e "    on ${hosts[${i}]} {"
    echo -e "        address\t${servers[${i}]}:7789;    }"
done
)
}
EOF

#############
# init drbd #
#############
apt install -y drbd8-utils
for i in ${mount_point[@]}
do
	[[ -d "${i}" ]] && mkdir /srv/$i
done

if [[ $(ip a | grep "inet ${servers[0]/}") ]]
then
	print "info" "server is primary"
	primary
else
	print "info" "server is secondary"
	secondary
fi

