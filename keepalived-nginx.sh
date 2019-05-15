vrrp_script chk_docker_nginx {
    script "/bin/bash /etc/keepalived/docker.sh"
    interval 3
    weight -4
    fall 1
    rise 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface enp0s8
    virtual_router_id 60
    priority 100
    advert_int 5
    authentication {
        auth_type AH
        auth_pass qwerty1234
    }
    unicast_src_ip 192.168.1.3
    unicast_peer {
        192.168.1.2
    }
    virtual_ipaddress {
        192.168.1.10/24
    }
    track_script {
        chk_docker_nginx
    }
    notify /etc/keepalived/keepalivednotify_web.sh
}
