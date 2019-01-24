#!/bin/bash
## cloud-init bootstrap script

set -x 

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


cat > /tmp/secrets.properties << EOF
tsm_admin_user=${Username}
tsm_admin_pass=${Password}
tableau_server_admin_user=${TableauServerAdminUser} 
tableau_server_admin_pass=${TableauServerAdminPassword}
EOF

sudo chmod 640 /tmp/secrets.properties



# Temporarily using OCI OS
#curl -f -s https://raw.githubusercontent.com/cloud-partners/oci-tableau/master/scripts/automated-installer \
 -o /tmp/automated-installer \
 --retry $10 --retry-max-time 60
curl -f -s https://objectstorage.us-phoenix-1.oraclecloud.com/n/intmahesht/b/pinkesh/o/automated-installer  -o /tmp/automated-installer --retry 0 --retry-max-time 60

sudo chmod 550 /tmp/automated-installer



cat > /tmp/config.json << EOF
{
  "configEntities": {
    "gatewaySettings": {
      "_type": "gatewaySettingsType",
      "port": 80,
      "firewallOpeningEnabled": true,
      "sslRedirectEnabled": true,
      "publicHost": "localhost",
      "publicPort": 80
    },
    "identityStore": {
      "_type": "identityStoreType",
      "type": "local"
    }
  }
}
EOF



cat > /tmp/registration.json << EOF
{
  "first_name": "${reg_first_name}",
  "last_name": "${reg_last_name}",
  "email": "${reg_email}",
  "company": "${reg_company}",
  "title": "${reg_title}",
  "department": "${reg_department}",
  "industry": "${reg_industry}",
  "phone": "${reg_phone}",
  "city": "${reg_city}",
  "state": "${reg_state}",
  "zip": "${reg_zip}",
  "country": "${reg_country}"
}
EOF

# Various machine configs
hostnamectl set-hostname $(hostnamectl --static)
setup_sftp() {
    source '/tmp/secrets.properties'
    useradd -m $tsm_admin_user
    echo -e "$tsm_admin_pass\n$tsm_admin_pass" | passwd $tsm_admin_user

    mkdir /restricted
    chown root:root /restricted
    chmod 551 /restricted
    sed -i.bak -e 's:Subsystem\\s\\+sftp\\s\\+/usr/libexec/openssh/sftp-server:Subsystem sftp  internal-sftp:' /etc/ssh/sshd_config
    printf "\\nMatch User $tsm_admin_user\\n  ForceCommand internal-sftp\\n  ChrootDirectory /restricted\\n  PasswordAuthentication yes\\n  AllowTcpForwarding no\\n  PermitTunnel no\\n  X11Forwarding no\\n" >>/etc/ssh/sshd_config
    service sshd restart
}
setup_sftp
unset -f setup_sftp


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
        # mount first disk to /var/opt/tableau - so it can be used for Tableau data.
        if [ $dcount -eq 0 ] ; then
                echo -e "Mounting /dev/$disk to /var/opt/tableau"
                sudo mkdir -p /var/opt/tableau
                sudo mount -o noatime,barrier=1 -t ext4 /dev/$disk /var/opt/tableau
                UUID=`sudo lsblk -no UUID /dev/$disk`
                echo "UUID=$UUID   /var/opt/tableau   ext4   defaults,noatime,discard,barrier=0 0 1" | sudo tee -a /etc/fstab 
        else
	        echo -e "Mounting /dev/$disk to /data$dcount"
	        sudo mkdir -p /data$dcount
	        sudo mount -o noatime,barrier=1 -t ext4 /dev/$disk /data$dcount
	        UUID=`sudo lsblk -no UUID /dev/$disk`
	        echo "UUID=$UUID   /data$dcount    ext4   defaults,noatime,discard,barrier=0 0 1" | sudo tee -a /etc/fstab
        fi
}

block_data_mount () {
        # mount first disk to /var/opt/tableau - so it can be used for Tableau data.  
        if [ $dcount -eq 0 ] ; then
                echo -e "Mounting /dev/$disk to /var/opt/tableau"
                sudo mkdir -p /var/opt/tableau
                sudo mount -o noatime,barrier=1 -t ext4 /dev/$disk /var/opt/tableau
                UUID=`sudo lsblk -no UUID /dev/$disk`
                echo "UUID=$UUID   /var/opt/tableau    ext4   defaults,_netdev,nofail,noatime,discard,barrier=0 0 2" | sudo tee -a /etc/fstab
        else
	        echo -e "Mounting /dev/$disk to /data$dcount"
	        sudo mkdir -p /data$dcount
	        sudo mount -o noatime,barrier=1 -t ext4 /dev/$disk /data$dcount
	        UUID=`sudo lsblk -no UUID /dev/$disk`
	        echo "UUID=$UUID   /data$dcount    ext4   defaults,_netdev,nofail,noatime,discard,barrier=0 0 2" | sudo tee -a /etc/fstab
	fi
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



###############################
## Install Tableau Server
###############################
install() {
    source '/tmp/secrets.properties'
    local license=''
    local license=$([ "$license" == '' ] && echo '' || echo "-k '$license'")
    bash /tmp/automated-installer -a $tsm_admin_user -f /tmp/config.json -r /tmp/registration.json -s /tmp/secrets.properties $license -v --accepteula --force $${tableau_server_package} 
    source /etc/profile.d/tableau_server.sh
    tsm topology nodes get-bootstrap-file --file bootstrap.cfg -u $tsm_admin_user -p $tsm_admin_pass
}
install
unset -f install

# publish the Primary xml
mv bootstrap.cfg /restricted/

## Tableau deployment complete. 
touch /tmp/complete


# Cleanup
rm -f /tmp/config.json
rm -f /tmp/registration.json
rm -f /tmp/automated-installer
rm -f /bvcount
echo "boot.sh.tpl setup complete"
set +x 
