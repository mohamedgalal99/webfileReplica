#!/bin/bash
source print.sh

servers=($@)
r_name="r0"
script_dir="$(pwd)"
drbd_disks=()
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
	drbdadm create-md ${r_name}
	drbdadm up ${r_name}
	drbdadm primary --force ${r_name}
	for (( i =0; i < ${#drbd_disks[@]}; i++ ))
	do
		mount ${drbd_disks[${i}]} ${mount_point[${i}]}
	done

}
function secondary ()
{
	drbdadm create-md ${r_name}
	drbdadm up ${r_name}
}

print "info" "Going to install DRBD"

# Postifix will be installed so I will bass it's interactive window
debconf-set-selections <<< "postfix postfix/mailname string ${hostname}.com"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'No Configuration'"

modinfo drbd
apt install -y drbd8-utils

print "info" "Disable postfix :D"
disable_service postfix

# checking that i connect to all other nodes and dump their hostname to my hosts if not there if ssh key not exchanged between ur hosts, and u did that manually hash this section and add arry of hosts

########################################
# Checking connectoin to other servers #
########################################

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
[[ ! -d "${drbd_dir}" ]] && mkdir ${drbd_dir}

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

cat << EOF > "${drbd_dir}/${r_name}.res"
resource ${r_name} {
$( 
for (( i = 0 ; i < ${#disks[@]} ; i++ ))
do
    echo -e "\tvolume ${i} {" 
    echo -e "\t\tdevice\t/dev/drbd${i};"
    drbd_disks=(${drbd_disks[@]} "/dev/drbd${i}")
    echo -e "\t\tdisk\t${disks[${i}]};"
    echo -e "\t\tmeta-disk\tinternal;\n\t}"
    
done
)
$(
for (( i = 0 ; i < ${#hosts[@]} ; i++ ))
do
    echo -e "\ton ${hosts[${i}]} {"
    echo -e "\t\taddress\t${servers[${i}]};"
    echo -e "\t\tmeta-disk\tinternal;\n\t}"
done
)
}
EOF

#############
# init drbd #
#############
if [[ $(ip a | grep "inet ${servers[0]/}") ]]
then
	primary
else
	secondary
fi

