#!/bin/bash

floating_ip="192.168.1.10"
netmask=24
floating_iface="enp0s8"
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
	ip -4 -o a s "${floating_iface}" | grep "${floating_ip}/${netmask}" &> /dev/null
	return $?
}

function primary ()
{
	echo "Start primary function"
	drbdadm primary ${drbd_name}
	for (( i =0; i < ${#disks[@]}; i++ ))
	do
		echo "${disks[${i}]} on ${mount_point[${i}]}"
		mount | grep "${disks[${i}]} on ${mount_point[${i}]} " &> /dev/null
		if [[ $? != 0 ]]
		then
			mount ${disks[${i}]} ${mount_point[${i}]}
		fi
	done
	state=0
	echo "End primary function"
	return 0
}
function secondary ()
{
	echo "Start Sec function"
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
	return 1
}

init_statue

if [[ "${cstate}" != "Connected" ]]
then
	return 1
else
	current_role=$(echo ${role} | awk -F/ '{print $1}')
	if [[ "${current_role}" = "Primary" ]]
	then
		echo "prim"
		if [[ ${test_floating} = 0 ]]
		then
			primary
		else
			echo "damn"
			secondary
		fi
	elif [[ "$(echo ${role} | grep Primary)" ]]
	then
		echo "sec"
		secondary
	else
		primary
	fi
fi

