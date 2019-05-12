#!/bin/bash

TYPE=$1
NAME=$2
STATE=$3

case $STATE in
	"MASTER") 
		echo "MASTER" > /etc/keepalived/status
		systemctl start nfs-server.service
		/bin/bash /etc/keepalived/drbd_ha.sh "MASTER"
		exit 0
		;;
        "BACKUP") 
		echo "BACKUP" > /etc/keepalived/status
		systemctl stop nfs-server.service
		/bin/bash /etc/keepalived/drbd_ha.sh "BACKUP"
		exit 0
		;;
	"FAULT")
		echo "FAULT" > /etc/keepalived/status
		systemctl stop nfs-server.service "FAULT"
		exit 0
		;;
	*)
		echo "unknown state"
		exit 1
		;;
esac
