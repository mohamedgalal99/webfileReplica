#!/bin/bash
# Title          :raid.sh
# Description    :This script used to formate disks and create raid 1 from them, it take set of disks needed
# Author         :Mohamed Galal
# Example        :# bash raid.sh sdb sdc

disks=($@)

function print ()
{
	red="\033[1;31m"
	green="\033[1;32m"
	yellow="\033[1;33m"
	blue="\033[1;34m"
	reset="\033[0m"
	state=$1
    message=$2
	order=${3:-0}
    if [[ "${state}" == "ok" || "${state}" = "+" ]]
	then
		for i in $(seq 1 ${order}); do echo -en "\t"; done
		echo -en "${green}[${state^^}] ${reset}${message}\n"
	elif [[ "${state}" == "err" ]]
	then
		for i in $(seq 1 ${order}); do echo -en "\t"; done
		echo -en "${red}[ERROR] ${reset}${message}\n"
	elif [[ "${state}" == "info" ]]
	then
		for i in $(seq 1 ${order}); do echo -en "\t"; done
		echo -en "${blue}[INFO] ${reset}${message}\n"
	else
		echo -en "$1\n"
	fi
}

function disk_format ()
{
	disk=${1:-xxx}
	[[ "${disk}" = "xxx" ]] && { print "err" "Disk_formate function need disk" "1"; exit 1; }
	print "info" "Formating /dev/${disk}" "1"
	dd if=/dev/zero of=/dev/${disk}  bs=512  count=1
	parted -s -a optima /dev/${disk} mklabel gpt
	parted -s /dev/${disk} mkpart primary ext4 0 100% &> /dev/null
	parted -s /dev/${disk} set 1 raid on
	print "ok" "Disk /dev/${disk} formated" "1"
}

function raid_create ()
{
	disks=($@)
	partitions=()
	[[ ${#disks[@]} -lt 2 ]] && { print "err" "Need at least 2 disks to create raid1" "1"; exit 1; }
	for (( i = 0; i < ${#disks[@]}; i++ ))
	do
		partitions=(${partitions[@]} /dev/${disks[${i}]}1)
	done
	mdadm --create /dev/md0 --level=mirror --metadata=0.90 --raid-devices=${#partitions[@]} ${partitions[@]}
	[[ $? = 0 ]] && print "ok" "RAID 1 created" "1" || { print "err" "Faild to create RAID 1" "1"; exit; }
}

# Check disks 
disk_check_status=0
print "info" "Going to check disks exist ..."
for i in ${disks[@]}
do
    disk_check=$(lsblk | grep -E "${i}[1-9]?\s" | wc -l)
	if [[ ${disk_check} != 1 ]]
	then
	    [[ ${disk_check} = 0 ]] && { print "err" "This disk ${i} doesn't exist" "1"; disk_check_status=1; continue; }
		print "err" "This disk ${i} is formated and there is partations created, please check" "1"
		disk_check_status=1
	else
	    print "ok" "Disks ${i} is ok" "1"
	fi
done
[[ ${disk_check_status} = 1 ]] && { echo -e "\n"; print "info" "Please check disks and re-run again." "1"; exit 1; }

# Formate disk Disks
print "info" "Going to wipe disks ..."
for disk in ${disks[@]}
do
	disk_format "${disk}"
done

# Creating RAID
dpkg -l | grep mdadm &> /dev/null
[[ $? != 0 ]] && { print "info" "Installing mdadm package"; apt install mdadm -y; }

print "info" "Creating RAID 1"
raid_create ${disks[@]}

exit 0
