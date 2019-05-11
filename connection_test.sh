#!/bin/bash
source print.sh
servers=($@)

function send_ssh_command ()
{
	[[ ${#@} != 2 ]] && { echo "[-] send_ssh_command function take only two args"; exit 1; }
	ip=$1
	comma=$2
	name=''
	name=$(ssh -A -q -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -o "ConnectTimeout=4" -o "PasswordAuthentication=no" -o "PubkeyAuthentication=yes" root@${ip} "hostname")
	echo "${name}"
}

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
	fi
done
