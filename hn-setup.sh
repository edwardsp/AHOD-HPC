#!/bin/bash

USER=hpcuser

IP=`ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
localip=`echo $IP | cut --delimiter='.' -f -3`

echo "*               hard    memlock         unlimited" >> /etc/security/limits.conf
echo "*               soft    memlock         unlimited" >> /etc/security/limits.conf

mkdir -p /home/$USER/.ssh
mkdir -p /home/$USER/bin
mkdir -p /mnt/resource/scratch
mkdir -p /mnt/nfsshare

mkdir /mnt/resource/scratch/
mkdir /mnt/resource/scratch/applications
mkdir /mnt/resource/scratch/INSTALLERS
mkdir /mnt/resource/scratch/benchmark

wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm

rpm -ivh epel-release-7-9.noarch.rpm
yum install -y -q nfs-utils nmap htop pdsh
#yum groupinstall -y "X Window System"
#npm install -g azure-cli

cat << EOF >> /etc/exports
/home $localip.*(rw,sync,no_root_squash,no_all_squash)
/mnt/resource/scratch $localip.*(rw,sync,no_root_squash,no_all_squash)
EOF

systemctl enable rpcbind
systemctl enable nfs-server
systemctl enable nfs-lock
systemctl enable nfs-idmap
systemctl start rpcbind
systemctl start nfs-server
systemctl start nfs-lock
systemctl start nfs-idmap
systemctl restart nfs-server

mv clusRun.sh cn-setup.sh /home/$USER/bin
chmod +x /home/$USER/bin/*.sh
chown $USER:$USER /home/$USER/bin
wget -q https://raw.githubusercontent.com/tanewill/AHOD-HPC/master/full-pingpong.sh -O /home/$USER/full-pingpong.sh
chmod 755 /home/$USER/full-pingpong.sh
chown $USER:$USER /home/$USER/full-pingpong.sh

cat << EOF >> /home/$USER/.bashrc
if [ -d "/opt/intel/impi" ]; then
    source /opt/intel/impi/*/bin64/mpivars.sh
fi
export I_MPI_FABRICS=shm:dapl
export I_MPI_DAPL_PROVIDER=ofa-v2-ib0
export I_MPI_DYNAMIC_CONNECTION=0
export I_MPI_DAPL_TRANSLATION_CACHE=0
EOF
chown $USER:$USER /home/$USER/.bashrc

nmap -sn $localip.* | grep $localip. | awk '{print $5}' > /home/$USER/bin/nodeips.txt
myhost=`hostname -i`
sed -i '/\<'$myhost'\>/d' /home/$USER/bin/nodeips.txt
sed -i '/\<10.0.0.1\>/d' /home/$USER/bin/nodeips.txt

ssh-keygen -f /home/$USER/.ssh/id_rsa -t rsa -N ''
cat << EOF > /home/$USER/.ssh/config
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    PasswordAuthentication no
EOF
cat /home/$USER/.ssh/id_rsa.pub >> /home/$USER/.ssh/authorized_keys
chmod 644 /home/$USER/.ssh/config
chown $USER:$USER /home/$USER/.ssh/*

# Don't require password for HPC user sudo
echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
# Disable tty requirement for sudo
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers



