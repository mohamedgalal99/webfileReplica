#!/bin/bash

script_path="$(pwd)"
print "info" "installing docker"
apt install docker.io

docker_path=$(which docker)
[[ -z "${docker_path}" ]] && { print "err" "docker command not found"; exit 1; }

if [[ -f "${script_path}/dock/Dockerfile" ]]
then
	print "info" "Going to build docker image for nginx, this gona take sometime :)"
	img_id=$(${docker_path} build ${script_path}/dock/ | grep "Successfully built" | awk '{print $NF}')
	[[ -z "${img_id}" ]] && { print "err" "Faild to build image"; exit 1; } || print "ok" "imge built ${img_id}"

	log_file="/var/log/nginx/"
	[[ -d "${log_file}" ]] && mkdir -p "${log_file}"
	root_dir="/srv/data"
	[[ -d "${root_dir}" ]] && mkdir -p "${root_dir}"

	docker run -itd -p 80:80 \ 
   	-v "${script_path}"/nginx/sites-enabled:/etc/nginx/sites-enabled \
   	-v "${script_path}"nginx/sites-available:/etc/nginx/sites-available \
   	-v "${script_path}"/nginx/conf.d:/etc/nginx/conf.d \
   	-v "${log_file}":/var/log/nginx \
   	-v "${root_dir}":/var/www/html \
   	--name nginx-$(date +%s) ${img_id}
fi
