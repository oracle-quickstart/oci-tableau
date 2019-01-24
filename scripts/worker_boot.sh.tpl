#!/bin/bash -x

THIS_FQDN=`hostname --fqdn`
THIS_HOST=$${THIS_FQDN%%.*}


#######################################################"
################# Turn Off the Firewall ###############"
#######################################################"
echo "Turning off the Firewall..."
which apt-get &> /dev/null
if [ $? -eq 0 ] ; then
    echo "" > /etc/iptables/rules.v4
    echo "" > /etc/iptables/rules.v6

    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
else
    service firewalld stop
    chkconfig firewalld off
fi


#######################################################"
#################   Update resolv.conf  ###############"
#######################################################"
## Modify resolv.conf to ensure DNS lookups work from one private subnet to another subnet
cp /etc/resolv.conf /etc/resolv.conf.backup
rm -f /etc/resolv.conf
echo "search ${PrivateSubnetsFQDN}" > /etc/resolv.conf
echo "nameserver 169.254.169.254" >> /etc/resolv.conf

#######################################################"

which apt-get &> /dev/null
if [ $? -eq 0 ] ; then
    apt-get update
    apt-get install -y python-setuptools
    apt-get install expect -y
    export LANG=en_US.UTF-8
    version_with_dash=`echo ${tableau_version} | sed  's|\.|-|g'` ; echo $version_with_dash
    tableau_server_package=tableau-server-$${version_with_dash}_amd64.deb
    tableau_server_package_url=https://downloads.tableau.com/esdalt/${tableau_version}/$tableau_server_package
    wget -O $tableau_server_package $tableau_server_package_url
    echo $tableau_server_package
else
    yum install epel-release -y
    yum install expect -y
    version_with_dash=`echo ${tableau_version} | sed  's|\.|-|g'` ; echo $version_with_dash
    tableau_server_package=tableau-server-$${version_with_dash}.x86_64.rpm
    tableau_server_package_url=https://downloads.tableau.com/esdalt/${tableau_version}/$tableau_server_package
    wget -O $tableau_server_package $tableau_server_package_url
    echo $tableau_server_package
fi


curl -f -s https://objectstorage.us-phoenix-1.oraclecloud.com/n/intmahesht/b/pinkesh/o/automated-installer  -o /tmp/automated-installer --retry 0 --retry-max-time 60
#curl -f -s https://raw.githubusercontent.com/cloud-partners/oci-tableau/master/scripts/automated-installer \
 -o /tmp/automated-installer \
 --retry $10 --retry-max-time 60
chmod 550 /tmp/automated-installer

cat > /tmp/secrets.properties << EOF
tsm_admin_user=qsadmin
tsm_admin_pass=alfred_genpass_32
tableau_server_admin_user=admin
tableau_server_admin_pass=alfred_genpass_32
EOF
chmod 640 /tmp/secrets.properties



# Various machine configs
hostnamectl set-hostname $(hostnamectl --static)
# Wait for Primary (use a random sleep to split up the requests and avoid throttling)
sleep $(($(expr $RANDOM % 30) * 3))

# get FQDN of tableau server (primary) 
primary_dns=`host tableau-server-1 | gawk '{ print $1 }'`
# primary_dns=${TableauPrimaryNodePrivateIP}


transfer() {
    source '/tmp/secrets.properties'
    expect -c "spawn sftp -o \"StrictHostKeyChecking no\" \"$tsm_admin_user@$primary_dns\";expect \"password:\";send \"$tsm_admin_pass\\n\";expect \"sftp>\";send \"get bootstrap.cfg\\n\";expect \"sftp>\";send \"exit\\n\";interact"
}


############################
## iscsi block volume setup
############################
#Look for all ISCSI devices in sequence, finish on first failure
v="0"
done="0"
echo -e "Mapping Block Volumes...."
for i in `seq 2 33`; do
        if [ $done = "0" ]; then
                sudo iscsiadm -m discoverydb -D -t sendtargets -p 169.254.2.$i:3260 2>&1 2>/dev/null
                iscsi_chk=`echo -e $?`
                if [ $iscsi_chk = "0" ]; then
                        echo -e "Success for volume $((i-1))."
                        v=$((v+1))
                        continue
                else
                        echo -e "Completed - $((i-2)) volumes found."
                        done="1"
                fi
        fi
done;
if [ $v -gt 0 ]; then
        echo -e "Setting auto-startup for $v volumes."
        sudo iscsiadm -m node -l
        sudo iscsiadm -m node -n node.startup -v automatic
fi
echo -e "$v" > /tmp/bvcount
sleep 5

###############################
## Primary Disk Mounting Function
###############################

data_mount () {
        echo -e "Mounting /dev/$disk to /data$dcount"
        sudo mkdir -p /data$dcount
        sudo mount -o noatime,barrier=1 -t ext4 /dev/$disk /data$dcount
        UUID=`sudo lsblk -no UUID /dev/$disk`
        echo "UUID=$UUID   /data$dcount    ext4   defaults,noatime,discard,barrier=0 0 1" | sudo tee -a /etc/fstab
}

block_data_mount () {
        echo -e "Mounting /dev/$disk to /data$dcount"
        sudo mkdir -p /data$dcount
        sudo mount -o noatime,barrier=1 -t ext4 /dev/$disk /data$dcount
        UUID=`sudo lsblk -no UUID /dev/$disk`
        echo "UUID=$UUID   /data$dcount    ext4   defaults,_netdev,nofail,noatime,discard,barrier=0 0 2" | sudo tee -a /etc/fstab
}


################################################
## Check for NVMe & block volume, mount them
################################################
## Check for x>0 devices
echo -n "Checking for disks..."
nvcount="0"
bvcount="0"
## Execute - will format all devices except sda for use as data disks
dcount=0
for disk in `cat /proc/partitions | grep -ivw 'sda' | grep -ivw 'sda[1-3]' | sed 1,2d | gawk '{print $4}'`; do
        echo -e "\nProcessing /dev/$disk"
        sudo mke2fs -F -t ext4 -b 4096 -E lazy_itable_init=1 -O sparse_super,dir_index,extent,has_journal,uninit_bg -m1 /dev/$disk
        nv_chk=`echo $disk | grep nv`;
        nv_chk=$?
        if [ $nv_chk = "0" ]; then
                nvcount=$((nvcount+1))
                data_mount
        else
                bvcount=$((bvcount+1))
                block_data_mount
        fi
        sudo /sbin/tune2fs -i0 -c0 /dev/$disk
        dcount=$((dcount+1))
done;
ibvcount=`cat /tmp/bvcount`
if [ $ibvcount -gt $bvcount ]; then
        echo -e "ERROR - $ibvcount Block Volumes detected but $bvcount processed."
else
        echo -e "DONE - $nvcount NVME disks processed, $bvcount Block Volumes processed."
fi


###############################################



transfer
unset -f transfer
# Install Tableau Server
install() {
    source '/tmp/secrets.properties'
    useradd -m "$tsm_admin_user"
    echo -e "$tsm_admin_pass\n$tsm_admin_pass" | passwd "$tsm_admin_user" 

    /tmp/automated-installer -a $tsm_admin_user -f /dev/zero -r /dev/zero -s /tmp/secrets.properties -b bootstrap.cfg -v --accepteula --force $${tableau_server_package}
}
install
unset -f install

## Tableau install complete
touch /tmp/complete


# Cleanup
rm -f /tmp/secrets.properties
rm -f /tmp/automated-installer
rm -f /bvcount
echo "worker_boot.sh.tpl setup complete"

