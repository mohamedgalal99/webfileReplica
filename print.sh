#!/bin/bash
# Title          :print.sh
# Description    :This script print color messages with ok, error, info status
# Author         :Mohamed Galal

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
