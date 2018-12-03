#!/bin/bash
# Script to configure Ubuntu for LDAP authentication - smah 5/8/2014

clear

# check if root user is logged in
if [ $(whoami) = "root" ] 
	then
	# root cannot be used as the userID
	logon=
else
#	logon=`whoami`
	echo "You must run this as root or with sudo, ie: sudo $0"		
	exit 1
fi

echo "This script will configure LDAP authentication for Ubuntu"
echo "Please back up everything in /etc before running this script, we are not responsible for broken systems!" 
echo "apt-get must be working, as certain packages must be installed during this process"
echo "A select few config files are backed up here: /etc/ldapbackup"
echo "Press a key to continue"
read -n 1
echo "Continuing..."

#check whether apt-get is functioning or not
sudo apt-get install at -y
if [[ $? > 0 ]]
then
    echo "apt-get does not appear to be working, please fix this and re-run this script"
    echo "exiting."
    exit
else
    echo "apt-get ran succesfuly, continuing with script."
fi

#backup config files:
mkdir -p /etc/ldapbackup
dest=/etc/ldapbackup

for F in etc/ldap.conf /etc/ldap/ldap.conf /etc/default/autofs /etc/auto.master /etc/nsswitch.conf /etc/nslcd.conf /etc/lightdm/lightdm.conf; do
if [ -f $F ]
then
echo backing up files: $F to $dest
cp $F $dest
fi
done

#download ldap certificate
wget http://engweb.eng.vmware.com/sipublic/ldap/ldap-eng-vmware.pem -O /etc/ssl/certs/ldap-eng-vmware.pem
chown root:root /etc/ssl/certs/ldap-eng-vmware.pem
chmod 644 /etc/ssl/certs/ldap-eng-vmware.pem

cat <<EOF1> /etc/defaultdomain.vmware
vmware.com
EOF1

# feed info to debcon-set-selections
cat <<EOF2>> /root/ldap-config.seed
ldap-auth-config        ldap-auth-config/bindpw password
ldap-auth-config        ldap-auth-config/rootbindpw     password
ldap-auth-config        ldap-auth-config/binddn string  cn=proxyuser,dc=example,dc=net
ldap-auth-config        ldap-auth-config/dbrootlogin    boolean false
ldap-auth-config        ldap-auth-config/rootbinddn     string  cn=manager,dc=example,dc=net
ldap-auth-config        ldap-auth-config/pam_password   select  md5
ldap-auth-config        ldap-auth-config/move-to-debconf        boolean true
ldap-auth-config        ldap-auth-config/ldapns/ldap-server     string  ldaps://ldap1-pao11.eng.vmware.com:636/ ldaps://ldap2-pao11.eng.vmware.com:636/
ldap-auth-config        ldap-auth-config/ldapns/base-dn string  dc=vmware,dc=com
ldap-auth-config        ldap-auth-config/override       boolean true
ldap-auth-config        ldap-auth-config/ldapns/ldap_version    select  3
ldap-auth-config        ldap-auth-config/dblogin        boolean false
nslcd   nslcd/ldap-bindpw       password
nslcd   nslcd/ldap-starttls     boolean false
nslcd   nslcd/ldap-base string  dc=vmware,dc=com
nslcd   nslcd/ldap-reqcert      select
nslcd   nslcd/ldap-uris string  ldaps://ldap1-pao11.eng.vmware.com:636/ ldaps://ldap2-pao11.eng.vmware.com:636/
nslcd   nslcd/ldap-binddn       string
libnss-ldapd    libnss-ldapd/nsswitch   multiselect     group, netgroup, passwd, shadow
libnss-ldapd    libnss-ldapd/clean_nsswitch     boolean false
EOF2

cat <<EOF3>> /etc/auto.master.vmware
+auto.master
EOF3


#installed required packages:
apt-get install autofs -y


# need debconf-utils to feed in ldap info with debconf-set-selections
apt-get install debconf-utils -y
debconf-set-selections /root/ldap-config.seed
apt-get install ldap-auth-client autofs-ldap nslcd libnss-ldapd -y
# setup ldap.conf
cat <<EOF4>> /etc/ldap.conf
SSL             no
TLS             hard
TLS_REQCERT     demand
TLS_CACERT      /etc/ssl/certs/ldap-eng-vmware.pem
BIND_POLICY     soft
EOF4

# copy to /etc/ldap, since auth-client-config only writes to /etc/ldap.conf
cp /etc/ldap.conf /etc/ldap/ldap.conf

auth-client-config -t nss -p lac_ldap

cat <<EOF5 >> /etc/default/autofs
MAP_OBJECT_CLASS="automountMap"
ENTRY_OBJECT_CLASS="automount"
MAP_ATTRIBUTE="ou"
ENTRY_ATTRIBUTE="cn"
VALUE_ATTRIBUTE="automountInformation"
EOF5

# ldap autofs fix
sed -r -i /etc/rc.local -e 's/exit 0//g'
cat <<EOF6>> /etc/rc.local
# Workaround for autofs problem at 1st bootup
sleep 15
service autofs restart
exit 0
EOF6

cp /etc/auto.master.vmware /etc/auto.master

cat <<EOF7 >> /etc/nsswitch.conf
automount: files ldap
EOF7

# Set netgroup correctly in nsswitch
sed -r -i /etc/nsswitch.conf -e 's/netgroup:[[:space:]]*.*/netgroup: ldap/'

# remove extraneous "uri " line
sed -i s/^uri\ $/#uri/g /etc/nslcd.conf

# fix ldap lightdm reference: http://www.tejasbarot.com/2014/04/25/hide-users-login-as-other-user-from-login-screen-ubuntu-14-04-lts-trusty-tahr/#axzz30emfVH8c
# keep in mind versions 12.04-13.10 has this command: /usr/lib/lightdm/lightdm-set-defaults
if [ -f /usr/lib/lightdm/lightdm-set-defaults ]
	then
# This means version is pre 14.04
/usr/lib/lightdm/lightdm-set-defaults --show-manual-login true
	else
# this means it's probably verison 14.04
cat <<EOF8 > /etc/lightdm/lightdm.conf
[SeatDefaults]
greeter-show-manual-login=true
greeter-hide-users=true
EOF8
fi


echo "Script completed, please reboot the system and login as your LDAP user account"
