#!/bin/bash

# Disable IPv6
sed -i s/"iface eth0 inet6 auto"/#"iface eth0 inet6 auto"/g /etc/network/interfaces

# Install firmware for b43
wget http://utso-deploy0.eng.vmware.com/drivers/broadcom/d630/b43.tar.gz -O /tmp/b43.tar.gz
cd /lib/firmware
tar xfz /tmp/b43.tar.gz

# System wide Proxy settings
cat <<EOF>> /etc/environment
http_proxy="http://proxy.vmware.com:3128"
ftp_proxy="http://proxy.vmware.com:3128"
no_proxy="eng.vmware.com, .vmware.com"
EOF

# Apt settings:
wget http://utso-deploy0.eng.vmware.com/ubuntu/ess-config/trusty/onemirror.list -O /etc/apt/sources.list

cat <<EOF>> /etc/apt/apt.conf
Acquire::http::Proxy "http://proxy.vmware.com:3128";
Acquire::http::Pipeline-Depth "0";
EOF

# Give ess sudo access
echo "ess ALL=(ALL) ALL" >>/etc/sudoers
echo "%mts ALL=(ALL) ALL" >>/etc/sudoers

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

# Laptop Specific Customization:

# sslvpn
wget http://utso-deploy0.eng.vmware.com/apps/sslvpn/network_connect.bz2 -O /tmp/network_connect.bz2
cd /tmp
mkdir -p /root/.juniper_networks
tar xfj /tmp/network_connect.bz2 -C /root/.juniper_networks/

# Configure Switchconf
wget http://utso-deploy0.eng.vmware.com/configs/switchconfig/switchconf-home.tar.gz -O /tmp/switchconf-home.tar.gz
cd /
tar xfz /tmp/switchconf-home.tar.gz
mkdir -p /etc/switchconf/work/etc/
cp /etc/environment /etc/switchconf/work/etc/
cp /etc/ntp.conf /etc/switchconf/work/etc/
cp -r /etc/apt /etc/switchconf/work/etc/

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
# Install laptop specific tools
apt-get install switchconf -y
#apt-get install sun-java6-plugin gsfonts-x11 java-common odbcinst1debian1 sun-java6-bin sun-java6-jre unixodbc -y
apt-get install icedtea6-plugin ca-certificates-java icedtea-6-jre-cacao openjdk-6-jre openjdk-6-jre-headless openjdk-6-jre-lib -y
apt-get install pidgin -y
apt-get install linux-headers-generic -y
# Install thinkfinger scanner
apt-get install thinkfinger-tools libpam-thinkfinger -y
# Install drivers for Intel Wireless 6000 series
#apt-get install linux-backports-modules-trusty-generic -y
apt-get install linux-backports-modules-wireless-trusty-generic -y
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
##lspci|grep VGA|grep -i ATI
##if [ "\$?" = "0" ]
	##then
	##apt-get install fglrx -y
	##aticonfig --initial
##fi
# packages oringally from lap.seed
apt-get install ntp build-essential thunderbird vim -y
apt-get clean -y

# We need to do it this way since installing apts with preconfigured items will prompt for user intervention
cp /etc/ntp.conf.vmware /etc/ntp.conf

# remove fast-user-switching
#apt-get remove fast-user-switch-applet -y

# also remove gconf entry for fast-user-switching
rm -rf /home/ess/.gconf/apps/panel/applets/fast_user_switch_screen0
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
echo "sh /root/update.sh" >> /root/.bashrc
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