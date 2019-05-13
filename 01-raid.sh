#!/bin/bash
# Title          :raid.sh
# Description    :This script used to formate disks and create raid 1 from them, it take set of disks needed
# Author         :Mohamed Galal
# Example        :# bash raid.sh sdb sdc

source print.sh
disks=($@)

apt install -y make make-guile gcc linux-headers-server build-essential psmisc bison flex linux-headers-$(name-r)



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
	#lsblk -l /dev/${disk} | grep ${disk} | tail -1 | awk '{print $1}'	# get last partion created in disk
	[[ ${#disks[@]} -lt 2 ]] && { print "err" "Need at least 2 disks to create raid1" "1"; exit 1; }
	for (( i = 0; i < ${#disks[@]}; i++ ))
	do
		partitions=(${partitions[@]} /dev/${disks[${i}]}1)  		# if disk isn't sdX1 this will be error
	done
	mdadm --create /dev/md0 --level=mirror --metadata=0.90 --raid-devices=${#partitions[@]} ${partitions[@]}  # need to optimize to get next available mdX
	[[ $? = 0 ]] && print "ok" "RAID 1 created" "1" || { print "err" "Faild to create RAID 1" "1"; exit; }
}

function lvm_create ()
{
	disk="$1"
	disk_prefix="$(echo ${disk} | awk -F/ '{print $NF}')"
	vg_name="$2"
	lv_name="$3"
	lv_size="$4"

	[[ "$(lsblk -l | grep -E "^${disk_prefix} ")" ]] && print "info" "Found disk" "1" || { print "err" "Can't detect disk ${disk}" "1"; exit 1; }
	
	# Create lvm_pv if not exist
	if [[ $(pvdisplay | grep -Ee "${disk}$") ]]
	then
		print "info" "Find PV Name exist" ""
	else
		pvcreate ${disk}
		print "info" "Creating pv" "1"
	fi
	# Create lvm_vg if not exist
	if [[ $(vgdisplay ${vg_name} 2> /dev/null) ]]
	then
		print "info" "Find Volume Groupe ${vg_name}" "1"
	else
		vgcreate ${vg_name} ${disk}
		print "ok" "Volume Groupe (r0) created successfully" "1"
	fi
	# Create lvm_lv
	lvcreate -L ${lv_size}G ${lv_name} ${vg_name} &&  print "ok" "Logical Volume ${lv_name} created" "1"
}

###############
# Check disks #
###############

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

#####################
#Formate disk Disks #
#####################

print "info" "Going to wipe disks ..."
for disk in ${disks[@]}
do
	disk_format "${disk}"
done

#################
# Creating RAID #
#################

dpkg -l | grep mdadm &> /dev/null
[[ $? != 0 ]] && { print "info" "Installing mdadm package"; apt install mdadm -y; }

print "info" "Creating RAID 1"
raid_create ${disks[@]}

print "info" "Create 2 LVM:\n  1- web: 3G\n  2- files: 10G "
lvm_create "/dev/md0" "r0" "web" "3"
lvm_create "/dev/md0" "r0" "files" "10"

exit 0
