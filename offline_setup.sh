#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/opt/bin:/opt/sbin:/data/root/bin

echo "Mounting rootfs as read-write..."
mount -o remount,rw /

echo "Fixing line endings..."
find /tmp/offline_files -type f -name "*.sh" -exec dos2unix {} +
find /tmp/offline_files -type f -name "*.service" -exec dos2unix {} +
find /tmp/offline_files -type f -name "atcmd*" -exec dos2unix {} +
find /tmp/offline_files -type f -name "killsmd7bridge" -exec dos2unix {} +
find /tmp/offline_files -type f -name ".profile" -exec dos2unix {} +
find /tmp/offline_files -type f -name "ttl-override" -exec dos2unix {} +
find /tmp/offline_files -type f -name "ttl-status" -exec dos2unix {} +
find /tmp/offline_files/repo/quectel-rgmii-toolkit-development-SDXLEMUR/simpleadmin/www/cgi-bin/ -type f -exec dos2unix {} +

echo "Installing Entware dependencies offline to /tmp/opt..."
mkdir -p /tmp/opt/bin /tmp/opt/etc /tmp/opt/lib/opkg /tmp/opt/tmp /tmp/opt/var/lock
cp /tmp/offline_files/opkg /tmp/opt/bin/opkg
chmod 755 /tmp/opt/bin/opkg
cp /tmp/offline_files/opkg.conf /tmp/opt/etc/opkg.conf
cd /tmp/offline_files
/tmp/opt/bin/opkg install *.ipk

echo "Creating persistent Entware backup..."
cd /tmp/opt
tar czf /data/opt_backup.tar.gz .


echo "Setting up SimpleAdmin directories..."
cp -r /tmp/offline_files/repo/quectel-rgmii-toolkit-development-SDXLEMUR/simpleadmin /data/
cp -r /tmp/offline_files/repo/quectel-rgmii-toolkit-development-SDXLEMUR/socat-at-bridge /data/
cp -r /tmp/offline_files/repo/quectel-rgmii-toolkit-development-SDXLEMUR/simplefirewall /data/

echo "Linking /opt for current session..."
rm -rf /data/opt
ln -s /tmp/opt /data/opt

# SimpleAdmin setup
echo "Configuring SimpleAdmin..."
mkdir -p /opt/etc/sudoers.d
echo "www-data ALL = (root) NOPASSWD: /usr/sbin/iptables, /usr/sbin/ip6tables, /data/simplefirewall/ttl-override, /bin/echo, /bin/cat" > /opt/etc/sudoers.d/www-data

openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=US/ST=MI/L=Romulus/O=RMIITools/CN=localhost" \
    -keyout /data/simpleadmin/server.key -out /data/simpleadmin/server.crt

cp /data/simpleadmin/systemd/* /lib/systemd/system/
chmod +x /data/simpleadmin/www/cgi-bin/*
chmod +x /data/simpleadmin/script/*
chmod +x /data/simpleadmin/console/menu/*
chmod +x /data/simpleadmin/console/.profile
cp -f /data/simpleadmin/console/.profile /data/root/.profile
chmod +x /data/root/.profile

chmod +x /data/simpleadmin/console/ttyd
chmod +x /data/simpleadmin/console/ttyd.bash
ln -sf /data/simpleadmin/console/ttyd /bin/ttyd
ln -sf /lib/systemd/system/ttyd.service /lib/systemd/system/multi-user.target.wants/
ln -sf /lib/systemd/system/lighttpd.service /lib/systemd/system/multi-user.target.wants/

# socat-at-bridge setup
echo "Configuring socat-at-bridge..."
cd /data/socat-at-bridge
chmod +x socat-armel-static killsmd7bridge atcmd atcmd11
ln -sf /data/socat-at-bridge/atcmd /bin
ln -sf /data/socat-at-bridge/atcmd11 /bin
cp -rf systemd_units/*.service /lib/systemd/system/

ln -sf /lib/systemd/system/socat-killsmd7bridge.service /lib/systemd/system/multi-user.target.wants/
ln -sf /lib/systemd/system/socat-smd11.service /lib/systemd/system/multi-user.target.wants/
ln -sf /lib/systemd/system/socat-smd11-to-ttyIN.service /lib/systemd/system/multi-user.target.wants/
ln -sf /lib/systemd/system/socat-smd11-from-ttyIN.service /lib/systemd/system/multi-user.target.wants/
ln -sf /lib/systemd/system/socat-smd7.service /lib/systemd/system/multi-user.target.wants/
ln -sf /lib/systemd/system/socat-smd7-to-ttyIN2.service /lib/systemd/system/multi-user.target.wants/
ln -sf /lib/systemd/system/socat-smd7-from-ttyIN2.service /lib/systemd/system/multi-user.target.wants/

# simplefirewall setup
echo "Configuring simplefirewall..."
cd /data/simplefirewall
chmod +x simplefirewall.sh ttl-override ttl-status
ln -sf /data/simplefirewall/simplefirewall.sh /bin
ln -sf /data/simplefirewall/ttl-override /bin
ln -sf /data/simplefirewall/ttl-status /bin
cp -rf systemd/*.service /lib/systemd/system/

ln -sf /lib/systemd/system/simplefirewall.service /lib/systemd/system/multi-user.target.wants/
ln -sf /lib/systemd/system/simplefirewall-reload.service /lib/systemd/system/multi-user.target.wants/

echo "Installing ttyd wrapper for boot-time persistence..."
# The ttyd binary is at /data/simpleadmin/console/ttyd
if [ ! -f /data/simpleadmin/console/ttyd.bin ]; then
    mv /data/simpleadmin/console/ttyd /data/simpleadmin/console/ttyd.bin
fi
cp /tmp/offline_files/ttyd_wrapper.sh /data/simpleadmin/console/ttyd
chmod +x /data/simpleadmin/console/ttyd
chmod +x /data/simpleadmin/console/ttyd.bin

echo "Offline setup complete! Services will start automatically."
# Manually invoke the wrapper once to start the services right now
/data/simpleadmin/console/ttyd &
