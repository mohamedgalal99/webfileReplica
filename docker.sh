#!/bin/bash

doc_path=$(which docker)

if [[ $(docker ps | grep "nginx-web" | grep ">80/tcp") ]]
then
	exit 0
else
	exit 1
fi
