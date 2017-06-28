#!/bin/bash
echo ##################################################
echo ############# Compute Node Setup #################
echo ##################################################
IPPRE=10.0.0.4

setsebool -P use_nfs_home_dirs 1

yum install -y -q nfs-utils htop pdsh
mkdir -p /mnt/resource/scratch
localip=`hostname -i | cut --delimiter='.' -f -3`
echo "$IPPRE:/home    /home   nfs defaults 0 0" | tee -a /etc/fstab
echo "$IPPRE:/mnt/resource/scratch    /mnt/resource/scratch   nfs defaults 0 0" | tee -a /etc/fstab
mount -a

