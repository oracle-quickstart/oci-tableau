#!/bin/bash -x

######################################
## Install Drivers for Data Sources ##
######################################

which apt-get &> /dev/null
if [ $? -eq 0 ] ; then
    ## Install drivers for Oracle, Postgresql & Essbase
    wget https://downloads.tableau.com/drivers/linux/deb/tableau-driver/tableau-postgresql-odbc_9.5.3_amd64.deb
    sudo gdebi tableau-postgresql-odbc_9.5.3_amd64.deb --n
    wget https://downloads.tableau.com/drivers/linux/deb/tableau-driver/tableau-oracle_12.1.0.2.0_amd64.deb
    sudo gdebi tableau-oracle_12.1.0.2.0_amd64.deb --n
    wget https://downloads.tableau.com/drivers/linux/deb/tableau-driver/tableau-essbase_11.1.2.4.0_amd64.deb
    sudo gdebi tableau-essbase_11.1.2.4.0_amd64.deb --n

    # Oracle instant client or similar client is only available for download after click-through agreement via Oracle OTN site to download rpms and install via alien
    # https://help.ubuntu.com/community/Oracle%20Instant%20Client
 
else     
    ## Install drivers for Oracle, Postgresql & Essbase
    wget https://downloads.tableau.com/drivers/linux/yum/tableau-driver/tableau-postgresql-odbc-9.5.3-1.x86_64.rpm
    sudo yum install tableau-postgresql-odbc-9.5.3-1.x86_64.rpm -y
    wget https://downloads.tableau.com/drivers/linux/yum/tableau-driver/tableau-oracle-12.1.0.2.0-1.x86_64.rpm
    sudo yum install tableau-oracle-12.1.0.2.0-1.x86_64.rpm -y
    wget https://downloads.tableau.com/drivers/linux/yum/tableau-driver/tableau-essbase-11.1.2.4.0-1.x86_64.rpm
    sudo yum install tableau-essbase-11.1.2.4.0-1.x86_64.rpm -y

    # Oracle instant client is available for auto-download without click-through license via below repo for rpm/yum install only.  
    cd /etc/yum.repos.d
    sudo wget http://yum.oracle.com/public-yum-ol7.repo
    sudo wget https://yum.oracle.com/RPM-GPG-KEY-oracle-ol7 -O /etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
    gpg --quiet --with-fingerprint /etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
    sudo yum install deltarpm -y
    sudo yum install yum-utils -y
    sudo yum-config-manager --enable ol7_oracle_instantclient
    sudo yum install oracle-instantclient18.3-basic.x86_64 -y
    sudo yum install oracle-instantclient18.3-sqlplus.x86_64  -y
    sudo yum install oracle-instantclient18.3-tools.x86_64  -y
    sudo yum install oracle-instantclient18.3-jdbc.x86_64  -y
    sudo yum install oracle-instantclient18.3-odbc.x86_64  -y
    cd -


    ## Install Oracle credentials wallet for authentication 

    if [ -f /tmp/oracle_credentials_wallet.zip ]; then
       echo -e "oracle_credentials_wallet.zip exist.  Continue with setup..."

       wallet_unzipped_folder=/tmp/oracle_credentials_wallet
       mkdir -p $wallet_unzipped_folder 
       unzip -u /tmp/oracle_credentials_wallet.zip -d $wallet_unzipped_folder
       chmod -R 777 $wallet_unzipped_folder 
       # Update file to point to the TNS_ADMIN location
       sed -i -E 's|DIRECTORY=".*"|DIRECTORY="/tmp/oracle_credentials_wallet"|g'  $wallet_unzipped_folder/sqlnet.ora
       tabsvc_file=/var/opt/tableau/tableau_server/.local/share/systemd/user/tabsvc_0.service
       ORACLE_HOME=/usr/lib/oracle/18.3/client64
       ## Clean up any old oracle config lines
       old_TNS_ADMIN_config=`cat $tabsvc_file | grep "^Environment=TNS_ADMIN="`
       old_LD_LIBRARY_PATH_config=`cat $tabsvc_file | grep "^Environment=LD_LIBRARY_PATH="`
       old_ORACLE_HOME_config=`cat $tabsvc_file | grep "^Environment=ORACLE_HOME="`
       sed -i "s|$old_TNS_ADMIN_config||g" $tabsvc_file
       sed -i "s|$old_LD_LIBRARY_PATH_config||g" $tabsvc_file
       sed -i "s|$old_ORACLE_HOME_config||g" $tabsvc_file

       ## Add new config
       search=`cat $tabsvc_file | grep Environment=LD_PRELOAD=`
       cp $tabsvc_file ${tabsvc_file}.backup
       sed -i "s|$search|$search\nEnvironment=TNS_ADMIN=$wallet_unzipped_folder\nEnvironment=LD_LIBRARY_PATH=$ORACLE_HOME/lib\nEnvironment=ORACLE_HOME=$ORACLE_HOME|g" $tabsvc_file

       ## need to login as tableau to restart the service
       sudo su -l tableau -c "systemctl --user restart  tabsvc_0 ; systemctl --user daemon-reload ; systemctl --user status tabsvc_0"
       # running it again, since sometimes the above config change are not effective unless the service is restarted again.
       sleep 10s
       sudo su -l tableau -c "systemctl --user restart  tabsvc_0 ; systemctl --user daemon-reload ; systemctl --user status tabsvc_0"
    fi
fi
echo "Install of drivers complete"
