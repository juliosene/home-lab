#! /bin/bash
#servers_ips=(10.0.0.10 10.0.0.11)
servers_ips=(#SERVER_IPS#)  # list of other servers in the pool
password="#USERPASSWD#"
user="#USERNAME#"

if service keepalived status | grep -F "MASTER STATE" &>/dev/null
then
#        echo "master"
        for i in ${servers_ips[@]}
        do
                rsync -ar --delete --rsync-path="sudo $user" --rsh="/usr/bin/sshpass -p $password ssh -o StrictHostKeyChecking=no -l $user" /etc/nginx/* rsync@$i:/etc/nginx/
        done

else
#        echo "backup"
fi