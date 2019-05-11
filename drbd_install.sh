#!/bin/bash

source print.sh

function disable_service ()
{
	service=$1
	systemctl is-enabled ${service} && { systemctl disable ${service}; systemctl stop ${service}; }
}


# We can modify this section later to add multi dist
file="/etc/apt/sources.list.d/drbd.list"
if [[ ! -f "${file}" ]]
then
	[[ $(lsb_release -c | awk '{print $2}') != "bionic" ]] && { print "err" "This drbd9 only for ubuntu bionic"; exit 1; }
	print "info" "Adding linbit-drbd to apt"
	touch ${file}
	cat < EOF > ${file}
	deb http://ppa.launchpad.net/linbit/linbit-drbd9-stack/ubuntu bionic main
	#deb-src http://ppa.launchpad.net/linbit/linbit-drbd9-stack/ubuntu bionic main
	EOF
	mv /etc/apt/trusted.gpg.d/linbit_ubuntu_linbit-drbd9-stack.gpg
	apt update
fi

print "info" "Going to install following packages drbd-utils python-drbdmanage drbd-dkms"

# Postifix will be installed so I will bass it's interactive window
debconf-set-selections <<< "postfix postfix/mailname string ${hostname}.com"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'No Configuration'"

apt install -y drbd-utils python-drbdmanage drbd-dkms
modinfo drbd
disable_service postfix
