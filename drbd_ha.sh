#!/bin/bash

floating_ip="192.168.1.10"
netmask=24
floating_iface="ens8"
disks=(
"/dev/drbd0"
"/dev/drbd1"
)
mount_point=(
"/srv/data"
"/srv/web"
)
drbd_name="r0"

role=""
cstate=""
dstate=""
state=""

function init_statue ()
{
	role=$(drbdadm role ${drbd_name} | head -1)
	cstate=$(drbdadm cstate ${drbd_name} | head -1)
	dstate=$(drbdadm dstate ${drbd_name} | head -1)
}
# will use later
function state ()
{
	last_mod=$(stat -t /proc/drbd)
	now=$(date +%s)
	diffrence= $(( ${now} - ${last_mod} ))
	if [[ ${diffrence} -lt 10 ]]
	then
		echo 0
	else
		echo 1
	fi
}
function test_floating ()
{
	if [[ $(ip -4 -o a s "${floating_iface}" | grep "${floating_ip}/${netmask}") ]]
	then
		echo "0"
	else
		echo "1"
	fi
}

function primary ()
{
	echo "Start primary function"
	drbdadm up ${drbd_name}
	drbdadm primary ${drbd_name}
	for (( i =0; i < ${#disks[@]}; i++ ))
	do
		#echo "${disks[${i}]} on ${mount_point[${i}]}"
		mount | grep "${disks[${i}]} on ${mount_point[${i}]} " &> /dev/null
		if [[ $? != 0 ]]
		then
			mount ${disks[${i}]} ${mount_point[${i}]}
		fi
	done
	state=0
	echo "End primary function"
}
function secondary ()
{
	echo "Start Sec function"
	drbdadm up ${drbd_name}
	for (( i =0; i < ${#disks[@]}; i++ ))
	do
		echo " ${disks[${i}]} on ${mount_point[${i}]}"
		mount | grep "${disks[${i}]} on ${mount_point[${i}]} " &> /dev/null
		if [[ $? = 0 ]]
		then
			fuser -k -9 ${mount_point[${i}]}
			sleep 2
			umount -f ${mount_point[${i}]}
		fi
	done
	drbdadm secondary ${drbd_name}
	state=1
	echo "End Sec function"
}

init_statue

state="$(cat /etc/keepalived/status)"
if [[ -z ${state} ]]
then
	[[ -f "/etc/keepalived/status" ]] && state=$(cat /etc/keepalived/status)    # what is this
fi

if [[ "${state}" = "MASTER" ]]
then
	primary
	exit 0
elif [[ "${state}" = "BACKUP" ]]
then
	secondary
	exit 0
elif [[ "${state}" = "FAULT" ]]
then
	secondary
	exit 0
else
	exit 1
fi
