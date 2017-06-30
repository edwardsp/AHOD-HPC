#!/bin/bash

USER=hpcuser

IP=`ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
localip=`echo $IP | cut --delimiter='.' -f -3`

cat << EOF >> /etc/security/limits.conf
*               hard    memlock         unlimited
*               soft    memlock         unlimited
EOF

mkdir -p /mnt/resource/scratch
mkdir /mnt/resource/scratch/
mkdir /mnt/resource/scratch/applications
mkdir /mnt/resource/scratch/INSTALLERS
mkdir /mnt/resource/scratch/benchmark

yum --enablerepo=extras install -y -q epel-release
yum install -y -q nfs-utils nmap htop pdsh screen

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

mkdir -p /home/$USER/bin
chown $USER:$USER /home/$USER/bin

cat << EOF >> /home/$USER/.bashrc
if [ -d "/opt/intel/impi" ]; then
    source /opt/intel/impi/*/bin64/mpivars.sh
fi
export PATH=/home/$USER/bin:\$PATH
export I_MPI_FABRICS=shm:dapl
export I_MPI_DAPL_PROVIDER=ofa-v2-ib0
export I_MPI_DYNAMIC_CONNECTION=0
export I_MPI_DAPL_TRANSLATION_CACHE=0
export WCOLL=/home/$USER/bin/hostlist
EOF
chown $USER:$USER /home/$USER/.bashrc

touch /home/hpcuser/bin/hostlist
chown hpcuser:hpcuser /home/hpcuser/bin/hostlist

ssh-keygen -f /home/$USER/.ssh/id_rsa -t rsa -N ''
cat << EOF > /home/$USER/.ssh/config
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    PasswordAuthentication no
    LogLevel QUIET
EOF
cat /home/$USER/.ssh/id_rsa.pub >> /home/$USER/.ssh/authorized_keys
chmod 644 /home/$USER/.ssh/config
chown $USER:$USER /home/$USER/.ssh/*

# Don't require password for HPC user sudo
echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
# Disable tty requirement for sudo
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

#
# base36ToDec script
#
cat << EOF > /home/$USER/bin/base36ToDec
#!/bin/bash
function getBase36()
{
        C=$1
        if [ -z "${C##[0-9]}" ]; then
                echo $C
        else
                echo "$(printf "%d" "'$C") - $(printf "%d" "'A") + 10" | bc
        fi
}
RES=0
for digit in $(echo $1 | grep -o .); do
        RES=$(echo "$RES * 36" | bc)
        RES=$(echo "$RES + $(getBase36 $digit)" | bc)
done
echo $RES
EOF
chown $USER:$USER /home/$USER/bin/base36ToDec
chmod 755 /home/$USER/bin/base36ToDec

#
# add .screenrc file
#
cat << EOF > /home/$USER/.screenrc
screen -t "top"  0 top
screen -t "bash 1"  0 bash

defscrollback 10000

sessionname local
shelltitle bash
startup_message off

vbell off

bind = resize =
bind + resize +2
bind - resize -2
bind _ resize max

caption always "%{= wr} $HOSTNAME %{= wk} %-Lw%{= wr}%n%f %t%{= wk}%+Lw %{= wr} %=%c %Y-%m-%d "


zombie cr
escape ^]]
EOF
chown $USER:$USER /home/$USER/.screenrc


# All reduce test
cat << EOF > /home/$USER/test_script.sh
for NPROCS in 1 2 4 8 16 32 64; do
	for PPN in 1 2 4 8 10 12 14 15 16; do
		NP=$(bc <<< "\$NPROCS * \$PPN")
		mpirun -np \$NP -ppn \$PPN -machinefile ~/bin/hostlist IMB-MPI1 Allreduce -npmin \$NP 2>&1 | tee IMB_Allreduce_\${NP}_\${NPROCS}x\${PPN}.log
	done
done
EOF
chown $USER:$USER /home/$USER/test_script.sh

# nmap for hosts (until better solution)
cat << EOF > /home/$USER/nmapForHosts.sh
IP=`ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
localip=`echo $IP | cut --delimiter='.' -f -3`
nmap -sn $localip.* | grep $localip. | awk '{print $5}' > /home/$USER/bin/nodeips.txt
myhost=`hostname -i`
sed -i '/\<'$myhost'\>/d' /home/$USER/bin/nodeips.txt
sed -i '/\<10.0.0.1\>/d' /home/$USER/bin/nodeips.txt
EOF
chown $USER:$USER /home/$USER/nmapForHosts.sh

