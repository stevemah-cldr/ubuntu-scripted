#!/bin/bash

# Disable IPv6
sed -i s/"iface eth0 inet6 auto"/#"iface eth0 inet6 auto"/g /etc/network/interfaces

# System wide Proxy settings
cat <<EOF>> /etc/environment
http_proxy="http://proxy.vmware.com:3128"
ftp_proxy="http://proxy.vmware.com:3128"
no_proxy="eng.vmware.com, .vmware.com"
EOF

# Apt settings:
cp /etc/apt/sources.list /etc/apt/sources.list.orig
wget http://utso-deploy0.eng.vmware.com/ubuntu/ess-config/trusty/onemirror.list -O /etc/apt/sources.list

cat <<EOF>> /etc/apt/apt.conf
Acquire::http::Proxy "http://proxy.vmware.com:3128";
Acquire::http::Pipeline-Depth "0";
EOF

# Give ess sudo access
echo "ess ALL=(ALL) ALL" >>/etc/sudoers
echo "%mts ALL=(ALL) ALL" >>/etc/sudoers

#download ldap certificate
wget http://engweb.eng.vmware.com/sipublic/ldap/ldap-eng-vmware.pem -O /etc/ssl/certs/ldap-eng-vmware.pem
chown root:root /etc/ssl/certs/ldap-eng-vmware.pem
chmod 644 /etc/ssl/certs/ldap-eng-vmware.pem

cat <<EOF> /etc/defaultdomain.vmware
vmware.com
EOF

# feed info to debcon-set-selections
cat <<EOF>> /root/ldap-config.seed
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
EOF

cat <<EOF>> /etc/auto.master.vmware
+auto.master
EOF

# setup one cups server
cat <<EOF>> /etc/cups/cupsd.conf
BrowsePoll cups-pao11.eng.vmware.com:631
BrowseInterval 120
EOF
#turn on Browsing for cups
cat /etc/cups/cupsd.conf|sed s/"Browsing Off"/"Browsing On"/g > /tmp/cupsd.conf
mv /tmp/cupsd.conf /etc/cups/cupsd.conf

# set up ntp
ntp1=`grep nameserver /etc/resolv.conf|head -1|cut -d' ' -f2`
ntp2=`grep nameserver /etc/resolv.conf|tail -1|cut -d' ' -f2`
cp /etc/ntp.conf /etc/ntp.conf.orig
cat <<EOF> /etc/ntp.conf.vmware
tinker panic 0
restrict default ignore
restrict 127.0.0.1
driftfile /var/lib/ntp/drift
broadcastdelay 0.008
#authenticate yes
#keys /etc/ntp/keys
logfile /var/log/ntpd
server $ntp1
restrict $ntp1 mask 255.255.255.255 nomodify notrap noquery
server $ntp2
restrict $ntp2 mask 255.255.255.255 nomodify notrap noquery
EOF

# Create default Firefox Preferences
mkdir -p /etc/skel/.mozilla/firefox/engsssig.default
cat <<EOF>> /etc/skel/.mozilla/firefox/engsssig.default/prefs.js
user_pref("browser.startup.homepage", "http://source.vmware.com");
user_pref("network.proxy.type", 4);
EOF
### Create profile file.
cat << EOF > /etc/skel/.mozilla/firefox/profiles.ini
[General]
StartWithLastProfile=1

[Profile0]
Name=default
IsRelative=1
Path=engsssig.default
Default=1
EOF

# copy default bookmarks
wget http://utso-deploy0.eng.vmware.com/apps/bookmarks/places.sqlite -O /etc/skel/.mozilla/firefox/engsssig.default/places.sqlite

# Create profile for ess user
cp -R /etc/skel/.mozilla /home/ess
chown ess.ess -R /home/ess/.mozilla

# set wallpaper
#### use jpg instead of bmp
#wget http://utso-deploy0.eng.vmware.com/ubuntu/ess-config/wallpaper/vmwareback.jpg -O /usr/share/backgrounds/vmwareback.jpg
wget http://utso-deploy0.eng.vmware.com/ubuntu/ess-config/wallpaper/vmwareback.jpg -O /usr/share/backgrounds/warty-final-ubuntu.png
wget http://utso-deploy0.eng.vmware.com/ubuntu/ess-config/wallpaper/wallpaper.xml -O /root/wallpaper.xml

# create script to: Run update after install during first bootup
cat <<EOF>> /root/update.sh
#!/bin/bash
#set default wallpaper and ess wallpaper
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults --load /root/wallpaper.xml
#sudo -u ess gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/vmwareback.jpg'
zenity --info --text "Please wait while Ubuntu updates are being applied" &
# To account for eth0 activation lag time
sleep 45
apt-get update
apt-get dist-upgrade -y
apt-get install ia32-libs -y
#apt-get install sun-java6-plugin gsfonts-x11 java-common odbcinst1debian1 sun-java6-bin sun-java6-jre unixodbc -y
#apt-get install icedtea6-plugin ca-certificates-java icedtea-6-jre-cacao openjdk-6-jre openjdk-6-jre-headless openjdk-6-jre-lib -y
apt-get install icedtea6-plugin ca-certificates-java icedtea-6-jre-cacao java-common libaccess-bridge-java libaccess-bridge-java-jni libjline-java openjdk-6-jre openjdk-6-jre-headless openjdk-6-jre-lib rhino tzdata-java -y
apt-get install pidgin -y
apt-get install ntp autofs build-essential thunderbird vim -y
apt-get install linux-headers-generic -y

#Install Nvidia Driver
#lspci|grep VGA|grep nVidia
lspci|grep VGA|grep -i nvidia
if [ "\$?" = "0" ]
	then
	apt-get install nvidia-current nvidia-settings -y
	nvidia-xconfig
fi
#Install ATI Driver
#lspci|grep VGA|grep ATI
###lspci|grep VGA|grep -i ATI
###if [ "\$?" = "0" ]
	###then
	###apt-get install fglrx -y
	###aticonfig --initial
###fi

function config_ldap_auth () {
# need debconf-utils to feed in nis domain with debconf-set-selections
apt-get install debconf-utils -y
debconf-set-selections /root/ldap-config.seed
apt-get install ldap-auth-client autofs-ldap nslcd libnss-ldapd -y
# setup ldap.conf
cat <<EOF1>> /etc/ldap.conf
SSL             no
TLS             hard
TLS_REQCERT     demand
TLS_CACERT      /etc/ssl/certs/ldap-eng-vmware.pem
BIND_POLICY     soft
EOF1

# copy to /etc/ldap, since auth-client-config only writes to /etc/ldap.conf
cp /etc/ldap.conf /etc/ldap/ldap.conf

auth-client-config -t nss -p lac_ldap

cat <<EOF3 >> /etc/default/autofs
MAP_OBJECT_CLASS="automountMap"
ENTRY_OBJECT_CLASS="automount"
MAP_ATTRIBUTE="ou"
ENTRY_ATTRIBUTE="cn"
VALUE_ATTRIBUTE="automountInformation"
EOF3

# ldap autofs fix
sed -r -i /etc/rc.local -e 's/exit 0//g'
cat <<EOF4>> /etc/rc.local
# Workaround for autofs problem at 1st bootup
sleep 15
service autofs restart
exit 0
EOF4

cp /etc/auto.master.vmware /etc/auto.master

# preconfigure ntp
cp /etc/ntp.conf.vmware /etc/ntp.conf

cat <<EOF5 >> /etc/nsswitch.conf
automount: files ldap
EOF5

# automount was not being populated
#sed -r -i /etc/nsswitch.conf -e 's/automount:[[:space:]]*.*/automount: files ldap/' 
 
# Set netgroup correctly in nsswitch
sed -r -i /etc/nsswitch.conf -e 's/netgroup:[[:space:]]*.*/netgroup: ldap/'

# remove extraneous "uri " line
sed -i s/^uri\ $/#uri/g /etc/nslcd.conf
# End of config_ldap_auth
}

### Need to make sure there are no lock files for apt-get before configuring LDAP Authentication
#apt-get install debconf-utils -y

if
	[ -f /var/lib/dpkg/lock ]
then
	echo "Kill processes and lock files..."
	echo "Waiting...ldap check was NOT successful" >> /var/log/siconfig.log
	pkill update-manager
	pkill software-center
	fuser -k /var/lib/dpkg/lock
	fuser -k /var/cache/apt/archives/lock
	apt-get update
	config_ldap_auth
        
else
	# run LDAP Configuration function
        config_ldap_auth      
        echo "Waiting... ldap check was successful" >> /var/log/siconfig.log	
fi
	
apt-get clean -y

# remove fast-user-switching
apt-get remove fast-user-switch-applet -y
# also remove gconf entry for fast-user-switching
rm -rf /home/ess/.gconf/apps/panel/applets/fast_user_switch_screen0
# run vmtools installation
sh /root/vmtools-install.sh
EOF
#################### end of update.sh script ####################


# create script to: Install Flash Plugin
cat <<EOF>> /root/install_flash.sh
#!/bin/bash
cd /tmp
wget http://utso-deploy0.eng.vmware.com/apps/flash/latest-flash.ini
ARCH=\`uname -m\`
TARBALL=\`grep \$ARCH /tmp/latest-flash.ini|grep latest|awk -F, '{print \$2}'\`
PLUGIN=\`grep \$ARCH /tmp/latest-flash.ini|grep latest|awk -F, '{print \$3}'\`
wget http://utso-deploy0.eng.vmware.com/apps/flash/\$TARBALL
tar xvfz /tmp/\$TARBALL
cp \$PLUGIN /usr/lib/mozilla/plugins
EOF
#Note: Also need to add entry: echo "sh /root/install_flash.sh" >> /root/.bashrc

# create script to: Install VMware Workstation after install during first bootup
cat <<EOF>> /root/install_vmware.sh
#!/bin/bash
zenity --info --text "Please wait while VMware Workstation is being installed" &
cd /tmp
wget http://utso-deploy0.eng.vmware.com/apps/vm-workstation/latest10.ini
# need to escape certain protected characters, variables
### Workstation 10
wrkst_package=\`grep x86_64 /tmp/latest10.ini |grep latest10|awk -F, '{print \$1}'\`
serial_number=\`grep serial /tmp/latest10.ini |grep latest|awk -F, '{print \$2}'\`
wget http://utso-deploy0.eng.vmware.com/apps/vm-workstation/\$wrkst_package
export VMWARE_EULAS_AGREED=yes
sh \$wrkst_package --console --required
/usr/lib/vmware/bin/vmware-vmx --new-sn \$serial_number
mkdir -p /home/administrator/.vmware
cp /etc/vmware/license* /home/administrator/.vmware
chown ess.ess /home/administrator/.vmware -R
mkdir -p /etc/skel/.vmware
cp /etc/vmware/license* /etc/skel/.vmware
EOF

# Give ess NOPASSWD
cp /etc/sudoers /etc/sudoers.bak
echo "ess ALL=NOPASSWD:ALL" >>/etc/sudoers

# make ess autologon & excute gnome-terminal
# fix ldap lightdm
# backup the original lightdm.conf
cat <<EOF>> /etc/lightdm/lightdm.conf
[SeatDefaults]
greeter-show-manual-login=true
greeter-hide-users=true
EOF
cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.bak

cat <<EOF> /etc/lightdm/lightdm.conf
[SeatDefaults]
greeter-session=unity-greeter
user-session=ubuntu
autologin-user=ess
EOF

#Create autostart for gnome-terminal
mkdir -p /home/ess/.config/autostart
cat <<EOF> /home/ess/.config/autostart/gnome-terminal.desktop
[Desktop Entry]
Type=Application
Encoding=UTF-8
Version=1.0
Name=No Name
Name[en_US]=gnome-terminal
Exec=/usr/bin/gnome-terminal
X-GNOME-Autostart-enabled=true
EOF
chown ess.ess -R /home/ess/.config
# make ess run as root
cp /home/ess/.bashrc /home/ess/.bashrc.bak
chown ess.ess /home/ess/.bashrc.bak
### Disable Screensaver & PowerManagement
echo "gconftool-2 --type boolean -s /apps/gnome-screensaver/idle_activation_enabled false" >> /home/ess/.bashrc
echo "gconftool-2 --type int -s /apps/gnome-power-manager/timeout/sleep_computer_ac 0" >> /home/ess/.bashrc
echo "gconftool-2 --type int -s /apps/gnome-power-manager/timeout/sleep_computer_battery 0" >> /home/ess/.bashrc
echo "gconftool-2 --type int -s /apps/gnome-power-manager/timeout/sleep_display_ac 0" >> /home/ess/.bashrc
echo "gconftool-2 --type int -s /apps/gnome-power-manager/timeout/sleep_display_battery 0" >> /home/ess/.bashrc
echo "sudo -i" >> /home/ess/.bashrc
# make root run updates and install vmware
cp /root/.bashrc /root/.bashrc.bak
echo "bash /root/update.sh" >> /root/.bashrc
echo "sh /root/install_vmware.sh" >> /root/.bashrc
echo "sh /root/install_flash.sh" >> /root/.bashrc
echo "sh /root/disable_autoinstall.sh" >> /root/.bashrc
#Create script to disable autostart, and bashrc files
cat <<EOF> /root/disable_autoinstall.sh
mv /etc/sudoers /etc/sudoers.new
mv /etc/sudoers.bak /etc/sudoers
#mv /etc/gdm/gdm.conf-custom /etc/gdm/gdm.conf-custom.new
#mv /etc/gdm/gdm.conf-custom.bak /etc/gdm/gdm.conf-custom
mv /etc/lightdm/lightdm.conf.bak /etc/lightdm/lightdm.conf
mv /etc/gdm/custom.conf /etc/gdm/custom.conf.bak
rm -rf /home/ess/.config/autostart/gnome-terminal.desktop
mv /home/ess/.bashrc /home/ess/.bashrc.new
mv /home/ess/.bashrc.bak /home/ess/.bashrc
mv /root/.bashrc /root/.bashrc.new
mv /root/.bashrc.bak /root/.bashrc
rm -rf /root/update.sh
rm -rf /root/install_vmware.sh

rm -rf /root/disable_autoinstall.sh
reboot
EOF