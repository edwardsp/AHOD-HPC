#!/bin/bash
echo ##################################################
echo ############# Compute Node Setup #################
echo ##################################################
IPPRE=$1
USER=hpcuser
if grep -q $IPPRE /etc/fstab; then FLAG=MOUNTED; else FLAG=NOTMOUNTED; fi

if [ $FLAG = NOTMOUNTED ] ; then 
    echo $FLAG
    echo installing NFS and mounting
    yum install -y -q nfs-utils htop pdsh
    mkdir -p /mnt/resource/scratch
    localip=`hostname -i | cut --delimiter='.' -f -3`
    echo "$IPPRE:/home    /home   nfs defaults 0 0" | tee -a /etc/fstab
    echo "$IPPRE:/mnt/resource/scratch    /mnt/resource/scratch   nfs defaults 0 0" | tee -a /etc/fstab
    mount -a
    df | grep $IPPRE

    cat << EOF >> /home/$USER/.bashrc
source /opt/intel/impi/*/bin64/mpivars.sh
export I_MPI_FABRICS=shm:dapl
export I_MPI_DAPL_PROVIDER=ofa-v2-ib0
export I_MPI_DYNAMIC_CONNECTION=0
export I_MPI_DAPL_TRANSLATION_CACHE=0
EOF

    wget -q https://raw.githubusercontent.com/tanewill/AHOD-HPC/master/full-pingpong.sh -O /home/$USER/full-pingpong.sh
    chmod +x /home/$USER/full-pingpong.sh
    chown $USER:$USER /home/$USER/full-pingpong.sh
else
    echo already mounted
    df | grep $IPPRE
fi
