#!/bin/bash

HEADNODE=10.0.0.4

mkdir -p /mnt/resource/scratch

cat << EOF >> /etc/fstab
$HEADNODE:/home    /home   nfs defaults 0 0
$HEADNODE:/mnt/resource/scratch    /mnt/resource/scratch   nfs defaults 0 0
EOF

yum --enablerepo=extras install -y -q epel-release
yum install -y -q nfs-utils htop pdsh
setsebool -P use_nfs_home_dirs 1

mount -a

echo $(hostname) >> /home/hpcuser/bin/hostlist
