# webfileReplica

- Server_NFS-01
	ips:
	10.0.0.2 ovs
	192.168.122.226
	floating_ip:
	10.0.0.10
- Server_NFS-02
	ips;
	10.0.0.3 ovs
	192.168.122.227
	floating_ip:
	10.0.0.10
- Server_web-01
	ips:
	10.0.0.4 ovs
	192.168.122.228
	floating_ip:
	10.0.0.200
- Server_web-02
	ips:
	10.0.0.5 ovs
	192.168.122.229
	floating_ip:
	10.0.0.200


On NFS Server:
	Task is divided to section to be compleated
		- make raid 1 between 2 disks to make sure if we lost one of disks don't lose data
		- install drbd 
		- configure drbd to use lv create in first step
		- install nfs server
		- install keepalived to provied healthy check 
		- making script to organize who is Primary/Slave integrated with keepalived and make 
		that node have floating ip is primary one and start nfs server if it's master node

	- Steps required to achive previous steps:
		I managed to run whole of installation baesd on 3 scripts which can linked togeather
		- 01-raid.sh
			This script take args which is disk we will make raid on then,
			# bash 01-raid.sh sdb sdc
			- Will check if disks id exist
			- is there is partations create on disks if yes, stop
			- formate disk and mark it as raid on
			- check if mdadm is installed
			- creating raid between provided disks
			- creating lv partions required, which supported at the begining of script
		- 02-drbd_install.sh
			open file and edit fist of it with args u need for this phase
			- make sure that primary server ip is first ip
			- lv disks created
			- mounting points
			- => then run
			- we will install drbd kernel module 
			- make sure it's loaded 
			- postfix is installed as one of packages so i managed to disable it as no need in our setup
			- testing that both nfs servers can conect each other with key, and server for itself too
			- creating drbd global_common.conf
				- make sure that we use protocol C , for sync
			- make sure that host name for all nfs node in hosts file 
			- creating drbd resource file (r0.res)
			- then start drbd with 2 condition
				- if server ip is first ip in arry provided then it's primary
				- else it's secondary
		- 03-keepalived-drbd.sh
			This script installing and configuring keepalived and make sure from HA of our NFS env
			- provide for it the following
				- network interface where keepalived will work on
				- floating ip we will use
				- server part from this HA
				- drbd disks
				- mount points
				- passwd auth
			- Installing NFS Server
				- geting ip mask to allow groups
				- calculating ip mask based on subnet of interface
				- creating config file /etc/export with following options
					- rw
					- sync
					- no_root_squash
					- no_subtree_check
				- Installing keepalived
				- copy scripts which we will based on them in healthy check
					drbd_ha.sh
					keeapalivednotift.sh
				- creating keepalivd.conf file
				- start and enable keepalived

- On Web servers
	Task is divided to section to be compleated
		- Nginx container
		- NFS client
		- keepalived

	- Installation will run only one script 04-webServerNodes.sh
		- open it and provide args like previous one
		- bash 04-webServerNodes.sh
			- Install docker if not installed
			- build nginx image based on docker file dock/Dockerfile
			- start container named => nginx-web <= with following ars
				- map ${script_path}"nginx/sites-available => /etc/nginx/sites-available
				- map ${script_path}"nginx/sites-enabled => /etc/nginx/sites-enabled
				- map ${script_path}"/nginx/conf.d => /etc/nginx/conf.d
				- map /var/log/nginx=> /var/log/nginx
				- map /srv/data => /var/www/html
			- Install NFS client
			- Install keepalived
			- copy following scripts to monitor nginx-web running, and mount shared NFS in /srv/data
				- docker.sh
				- keepalivednotify_web.sh
			- Creating keepalived config file
			- enable and start keepalived
