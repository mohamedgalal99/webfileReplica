#!/bin/bash

TYPE=$1
NAME=$2
STATE=$3

case $STATE in
	"MASTER") 
		echo "MASTER" > /etc/keepalived/status
		mount 192.168.1.10:/srv/data /srv/data
		docker start nginx_web 
		exit 0
		;;
        "BACKUP") 
		echo "BACKUP" > /etc/keepalived/status
		docker stop nginx_web
		umount /srv/data
		exit 0
		;;
	"FAULT")
		echo "FAULT" > /etc/keepalived/status
		docker stop nginx_web
		systemctl stop nfs-server.service "FAULT"
		exit 0
		;;
	*)
		echo "unknown state"
		exit 1
		;;
esac
