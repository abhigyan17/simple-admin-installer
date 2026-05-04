#!/bin/sh
# SimpleAdmin Offline Device Installer
# Runs ON the device from /tmp/install/
# Compatible: Foxconn B01W009 / OD523 (Qualcomm SDXLEMUR ARMv7)

INSTALL_DIR="$(dirname "$0")"
DATA_SIMPLEADMIN="/data/simpleadmin"
BACKUP_TAR="/data/opt_backup.tar.gz"
ETC_ADMIN="/etc/simpleadmin"

echo "=== SimpleAdmin Offline Installer ==="
hostname 2>/dev/null || true

# Step 1: Remount rootfs writable
echo "[1/11] Remounting rootfs rw..."
mount -o remount,rw /
mkdir -p "$ETC_ADMIN"

# Step 2: Set up /data/simpleadmin web directories
echo "[2/11] Setting up web directories..."
mkdir -p "$DATA_SIMPLEADMIN/www/cgi-bin" "$DATA_SIMPLEADMIN/www/css" \
         "$DATA_SIMPLEADMIN/www/js" "$DATA_SIMPLEADMIN/www/fonts"
if [ -d "$INSTALL_DIR/www" ]; then
    cp -r "$INSTALL_DIR/www/." "$DATA_SIMPLEADMIN/www/"
fi
if [ -d "$INSTALL_DIR/console" ]; then
    cp -r "$INSTALL_DIR/console" "$DATA_SIMPLEADMIN/"
    chmod +x "$DATA_SIMPLEADMIN/console/"*.bash 2>/dev/null || true
fi
if [ -d "$INSTALL_DIR/script" ]; then
    cp -r "$INSTALL_DIR/script" "$DATA_SIMPLEADMIN/"
    chmod +x "$DATA_SIMPLEADMIN/script/"*.sh 2>/dev/null || true
fi
chmod +x "$DATA_SIMPLEADMIN/www/cgi-bin/"* 2>/dev/null || true

# Fix user_atcommand: use microcom with timeout (avoids URC pollution on PTY bridge)
# The original script had 'atcmd '$x'' with single quotes - $x was never expanded.
printf '%s' 'IyEvYmluL2Jhc2gKUVVFUllfU1RSSU5HPSQoZWNobyAiJHtRVUVSWV9TVFJJTkd9IiB8IHNlZCAncy87Ly9nJykKZnVuY3Rpb24gdXJsZGVjb2RlKCkgeyA6ICIkeyovLysvIH0iOyBlY2hvIC1lICIke18vLyUvXFx4fSI7IH0KCmlmIFsgIiR7UVVFUllfU1RSSU5HfSIgXTsgdGhlbgogICAgZXhwb3J0IElGUz0iJiIKICAgIGZvciBjbWQgaW4gJHtRVUVSWV9TVFJJTkd9OyBkbwogICAgICAgIGlmIFsgIiQoZWNobyAkY21kIHwgZ3JlcCAnPScpIiBdOyB0aGVuCiAgICAgICAgICAgIGtleT0kKGVjaG8gJGNtZCB8IGF3ayAtRiAnPScgJ3twcmludCAkMX0nKQogICAgICAgICAgICB2YWx1ZT0kKGVjaG8gJGNtZCB8IGF3ayAtRiAnPScgJ3twcmludCAkMn0nKQogICAgICAgICAgICBldmFsICRrZXk9JHZhbHVlCiAgICAgICAgZmkKICAgIGRvbmUKZmkKCng9JCh1cmxkZWNvZGUgIiRhdGNtZCIpCk1ZQVRDTUQ9JChwcmludGYgJyViXG4nICIke2F0Y21kLy8lL1xjeH0iKQppZiBbIC1uICIke01ZQVRDTUR9IiBdOyB0aGVuCiAgICB3YWl0X3RpbWU9MjAwCiAgICB3aGlsZSB0cnVlOyBkbwogICAgICAgIHJ1bmNtZD0kKGVjaG8gLWVuICIkeFxyXG4iIHwgbWljcm9jb20gLXQgJHdhaXRfdGltZSAvZGV2L3R0eU9VVDIpCiAgICAgICAgaWYgW1sgJHJ1bmNtZCA9fiAiT0siIF1dIHx8IFtbICRydW5jbWQgPX4gIkVSUk9SIiBdXTsgdGhlbgogICAgICAgICAgICBicmVhawogICAgICAgIGZpCiAgICAgICAgKCggd2FpdF90aW1lIDwgNTAwMCApKSAmJiAoKCB3YWl0X3RpbWUrPTUwMCApKSB8fCBicmVhawogICAgZG9uZQpmaQoKZWNobyAiQ29udGVudC10eXBlOiB0ZXh0L3BsYWluIgplY2hvICR4CmVjaG8gIiIKZWNobyAiJHJ1bmNtZCI=' \
    | base64 -d > "$DATA_SIMPLEADMIN/www/cgi-bin/user_atcommand"
chmod +x "$DATA_SIMPLEADMIN/www/cgi-bin/user_atcommand"
echo "  CGI user_atcommand fixed."

# Step 3: Install socat-at-bridge (AT command PTY bridge for CGI scripts)
echo "[3/11] Installing socat-at-bridge..."
if [ -d "$INSTALL_DIR/socat-at-bridge" ]; then
    cp -r "$INSTALL_DIR/socat-at-bridge" /data/
    chmod +x /data/socat-at-bridge/socat-armel-static
    chmod +x /data/socat-at-bridge/atcmd
    chmod +x /data/socat-at-bridge/atcmd11
    chmod +x /data/socat-at-bridge/killsmd7bridge
    ln -sf /data/socat-at-bridge/atcmd /bin/atcmd 2>/dev/null || true
    echo "  socat-at-bridge installed from bundle."
elif [ -d /data/socat-at-bridge ]; then
    ln -sf /data/socat-at-bridge/atcmd /bin/atcmd 2>/dev/null || true
    echo "  socat-at-bridge already present."
else
    echo "  WARNING: socat-at-bridge not found - AT command CGI will not work."
fi

# Step 4: Generate SSL certificate
# Store cert on rootfs (/etc/simpleadmin/) not /data/ - /data/ is 100% full on these devices.
# Generate to /tmp first since OpenSSL cannot write to a near-full UBIFS partition.
# Clock is set to 2026 first so the cert gets valid dates.
echo "[4/11] Generating SSL certificate..."
date -s "2026-01-01 00:00:00" 2>/dev/null || true
openssl req -new -newkey rsa:2048 -days 36500 -nodes -x509 \
    -subj "/C=IN/O=SimpleAdmin/CN=192.168.1.1" \
    -keyout /tmp/sa_server.key \
    -out /tmp/sa_server.crt 2>/dev/null
cp /tmp/sa_server.crt "$ETC_ADMIN/server.crt"
cp /tmp/sa_server.key "$ETC_ADMIN/server.key"
rm -f /tmp/sa_server.crt /tmp/sa_server.key
echo "  Certificate created."

# Step 5: Set up entware in /tmp/opt
echo "[5/11] Setting up entware in /tmp/opt..."
if [ -f "$BACKUP_TAR" ]; then
    mkdir -p /tmp/opt
    tar -xzf "$BACKUP_TAR" -C /tmp/opt/
    echo "  Restored from backup."
elif [ -f "$INSTALL_DIR/opkg" ]; then
    echo "  Installing from IPK packages..."
    mkdir -p /tmp/opt/bin /tmp/opt/etc /tmp/opt/lib/opkg /tmp/opt/tmp /tmp/opt/var/lock
    cp "$INSTALL_DIR/opkg" /tmp/opt/bin/opkg && chmod 755 /tmp/opt/bin/opkg
    cp "$INSTALL_DIR/opkg.conf" /tmp/opt/etc/opkg.conf
    /tmp/opt/bin/opkg install "$INSTALL_DIR/"*.ipk
    echo "  Saving entware backup to $BACKUP_TAR..."
    tar -czf "$BACKUP_TAR" -C /tmp/opt .
else
    echo "ERROR: No opt_backup.tar.gz or IPK packages found in $INSTALL_DIR"
    exit 1
fi
echo "  Lighttpd: $(/tmp/opt/sbin/lighttpd -v 2>&1 | head -1)"

# Step 6: Set /opt symlink to /tmp/opt on rootfs
echo "[6/11] Setting /opt -> /tmp/opt..."
rm -f /opt 2>/dev/null || true
ln -s /tmp/opt /opt

# Step 7: Write post-restore.sh to rootfs (runs after each boot restore)
# This script recreates things that live in RAM (/tmp/opt) after every reboot.
echo "[7/11] Writing post-restore.sh..."
cat > "$ETC_ADMIN/post-restore.sh" << 'POSTEOF'
#!/bin/sh
# sudo passthrough - lighttpd runs as root, no privilege change needed
mkdir -p /tmp/opt/bin
printf '%s' 'IyEvYmluL3NoCmV4ZWMgIiRAIgo=' | base64 -d > /tmp/opt/bin/sudo
chmod 755 /tmp/opt/bin/sudo
# Set clock (no hardware RTC battery on this device)
date -s '2026-05-04 00:00:00' > /dev/null 2>&1 || true
POSTEOF
chmod 755 "$ETC_ADMIN/post-restore.sh"
echo "  post-restore.sh written."
sh "$ETC_ADMIN/post-restore.sh"

# Step 8: Write admin password to rootfs
echo "[8/11] Setting admin password..."
HASH=$(openssl passwd -apr1 'Asdf@12345' 2>/dev/null || openssl passwd -1 'Asdf@12345')
printf 'admin:%s\n' "$HASH" > "$ETC_ADMIN/.htpasswd"
echo "  Password hash written to $ETC_ADMIN/.htpasswd"

# Step 9: Write lighttpd.conf to rootfs
# Config is stored on rootfs so it survives reboots regardless of /data/ state.
echo "[9/11] Writing lighttpd.conf to rootfs..."
cat > "$ETC_ADMIN/lighttpd.conf" << 'CONFEOF'
server.modules = (
    "mod_redirect",
    "mod_cgi",
    "mod_proxy",
    "mod_openssl",
    "mod_auth",
    "mod_authn_file",
)

server.port = 8443
server.document-root = "/usrdata/simpleadmin/www"
index-file.names = ( "index.html" )

ssl.engine = "enable"
ssl.privkey= "/etc/simpleadmin/server.key"
ssl.pemfile= "/etc/simpleadmin/server.crt"
ssl.openssl.ssl-conf-cmd = ("MinProtocol" => "TLSv1.2")

auth.backend = "htpasswd"
auth.backend.htpasswd.userfile = "/etc/simpleadmin/.htpasswd"

auth.require = ( "/" => (
  "method" => "basic",
  "realm" => "Authorized users only",
  "require" => "valid-user"
  )
)

$HTTP["url"] =~ "/cgi-bin/" {
    cgi.assign = ( "" => "" )
}

$HTTP["url"] =~ "(^/console)" {
  proxy.header = ("map-urlpath" => ( "/console" => "/" ), "upgrade" => "enable" )
  proxy.server  = ( "" => ("" => ( "host" => "127.0.0.1", "port" => 8080 )))
}
CONFEOF
echo "  Config written."
/tmp/opt/sbin/lighttpd -tt -f "$ETC_ADMIN/lighttpd.conf" 2>&1 | grep -v Warning || true

# Step 10: Install systemd services to rootfs
echo "[10/11] Installing systemd services..."

cat > /lib/systemd/system/entware-restore.service << 'SVCEOF'
[Unit]
Description=Restore Entware from /data/opt_backup.tar.gz to /tmp/opt
DefaultDependencies=no
After=local-fs.target
Before=lighttpd.service network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'mkdir -p /tmp/opt && tar -xzf /data/opt_backup.tar.gz -C /tmp/opt/ && /etc/simpleadmin/post-restore.sh'

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /lib/systemd/system/lighttpd.service << 'SVCEOF'
[Unit]
Description=SimpleAdmin Lighttpd (HTTPS :8443)
After=network.target entware-restore.service
Wants=entware-restore.service

[Service]
Type=simple
PIDFile=/tmp/lighttpd.pid
ExecStartPre=/tmp/opt/sbin/lighttpd -tt -f /etc/simpleadmin/lighttpd.conf
ExecStart=/tmp/opt/sbin/lighttpd -D -f /etc/simpleadmin/lighttpd.conf
ExecReload=/bin/kill -USR1 $MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /lib/systemd/system/socat-killsmd7bridge.service << 'SVCEOF'
[Unit]
Description=Kill port_bridge on smd7 so socat-at-bridge can use it

[Service]
Type=oneshot
ExecStart=/usrdata/socat-at-bridge/killsmd7bridge

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /lib/systemd/system/socat-smd7.service << 'SVCEOF'
[Unit]
Description=Socat Serial Emulation for smd7
After=socat-killsmd7bridge.service

[Service]
ExecStart=/usrdata/socat-at-bridge/socat-armel-static -d -d pty,link=/dev/ttyIN2,raw,echo=0,group=20,perm=660 pty,link=/dev/ttyOUT2,raw,echo=1,group=20,perm=660
ExecStartPost=/bin/sleep 2s
Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /lib/systemd/system/socat-smd7-to-ttyIN2.service << 'SVCEOF'
[Unit]
Description=Read from /dev/smd7 and write to ttyIN2
BindsTo=socat-smd7.service
After=socat-smd7.service

[Service]
ExecStart=/bin/bash -c '/bin/cat /dev/smd7 > /dev/ttyIN2'
ExecStartPost=/bin/sleep 2s
StandardInput=null
Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /lib/systemd/system/socat-smd7-from-ttyIN2.service << 'SVCEOF'
[Unit]
Description=Read from /dev/ttyIN2 and write to smd7
BindsTo=socat-smd7.service
After=socat-smd7.service

[Service]
ExecStart=/bin/bash -c '/bin/cat /dev/ttyIN2 > /dev/smd7'
ExecStartPost=/bin/sleep 2s
StandardInput=null
Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /lib/systemd/system/socat-smd11.service << 'SVCEOF'
[Unit]
Description=Socat Serial Emulation for smd11
After=ql-netd.service

[Service]
ExecStart=/usrdata/socat-at-bridge/socat-armel-static -d -d pty,link=/dev/ttyIN,raw,echo=0,group=20,perm=660 pty,link=/dev/ttyOUT,raw,echo=1,group=20,perm=660
ExecStartPost=/bin/sleep 2s
Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /lib/systemd/system/socat-smd11-to-ttyIN.service << 'SVCEOF'
[Unit]
Description=Read from /dev/smd11 and write to ttyIN
BindsTo=socat-smd11.service
After=socat-smd11.service

[Service]
ExecStart=/bin/bash -c '/bin/cat /dev/smd11 > /dev/ttyIN'
ExecStartPost=/bin/sleep 2s
StandardInput=null
Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /lib/systemd/system/socat-smd11-from-ttyIN.service << 'SVCEOF'
[Unit]
Description=Read from /dev/ttyIN and write to smd11
BindsTo=socat-smd11.service
After=socat-smd11.service

[Service]
ExecStart=/bin/bash -c '/bin/cat /dev/ttyIN > /dev/smd11'
ExecStartPost=/bin/sleep 2s
StandardInput=null
Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
SVCEOF

# clock-set fires 30s after boot to override Qualcomm time_daemon.
# This device has no battery-backed RTC so time_daemon resets the clock
# to 1980-01-06 on every boot. The 30s delay lets time_daemon finish first.
cat > /lib/systemd/system/clock-set.service << 'SVCEOF'
[Unit]
Description=Set system clock (no hardware RTC battery)
After=time_serviced.service

[Service]
Type=oneshot
ExecStart=/bin/date -s '2026-05-04 00:00:00'

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /lib/systemd/system/clock-set.timer << 'SVCEOF'
[Unit]
Description=Set clock 30s after boot (after Qualcomm time_daemon finishes)

[Timer]
OnBootSec=30s
Unit=clock-set.service

[Install]
WantedBy=timers.target
SVCEOF

# ttyd terminal service
# ExecStartPost cleans up the stale lighttpd.service override that ttyd's
# startup script copies into /run/systemd/system/ on every boot.
if [ -f "$DATA_SIMPLEADMIN/console/ttyd" ] || [ -f "$DATA_SIMPLEADMIN/console/ttyd.bin" ]; then
    cat > /lib/systemd/system/ttyd.service << 'TTYEOF'
[Unit]
Description=TTYD Web Terminal
After=network.target entware-restore.service

[Service]
Type=simple
ExecStartPre=/bin/sleep 5
ExecStart=/usrdata/simpleadmin/console/ttyd -i 127.0.0.1 -p 8080 -t theme={} -t fontSize=25 --writable /usrdata/simpleadmin/console/ttyd.bash
ExecStartPost=/bin/sh -c 'sleep 4 && rm -f /run/systemd/system/lighttpd.service && systemctl daemon-reload && systemctl restart lighttpd'
Restart=on-failure

[Install]
WantedBy=multi-user.target
TTYEOF
    ln -sf /lib/systemd/system/ttyd.service \
        /etc/systemd/system/multi-user.target.wants/ttyd.service 2>/dev/null || true
fi

# Step 11: Enable and start services
echo "[11/11] Enabling and starting services..."
systemctl daemon-reload
rm -f /run/systemd/system/lighttpd.service 2>/dev/null || true

WANTS=/etc/systemd/system/multi-user.target.wants
mkdir -p "$WANTS" /etc/systemd/system/timers.target.wants
ln -sf /lib/systemd/system/entware-restore.service          "$WANTS/entware-restore.service"
ln -sf /lib/systemd/system/lighttpd.service                  "$WANTS/lighttpd.service"
ln -sf /lib/systemd/system/socat-killsmd7bridge.service      "$WANTS/socat-killsmd7bridge.service"
ln -sf /lib/systemd/system/socat-smd7.service                "$WANTS/socat-smd7.service"
ln -sf /lib/systemd/system/socat-smd11.service               "$WANTS/socat-smd11.service"
ln -sf /lib/systemd/system/socat-smd7-to-ttyIN2.service      "$WANTS/socat-smd7-to-ttyIN2.service"
ln -sf /lib/systemd/system/socat-smd7-from-ttyIN2.service    "$WANTS/socat-smd7-from-ttyIN2.service"
ln -sf /lib/systemd/system/socat-smd11-to-ttyIN.service      "$WANTS/socat-smd11-to-ttyIN.service"
ln -sf /lib/systemd/system/socat-smd11-from-ttyIN.service    "$WANTS/socat-smd11-from-ttyIN.service"
ln -sf /lib/systemd/system/clock-set.timer \
    /etc/systemd/system/timers.target.wants/clock-set.timer

systemctl start entware-restore 2>/dev/null || true
systemctl start socat-killsmd7bridge 2>/dev/null || true
systemctl start socat-smd7 2>/dev/null || true
systemctl start socat-smd11 2>/dev/null || true
sleep 3
systemctl start socat-smd7-to-ttyIN2 socat-smd7-from-ttyIN2 \
    socat-smd11-to-ttyIN socat-smd11-from-ttyIN 2>/dev/null || true
sleep 1
systemctl start lighttpd 2>/dev/null || true
sleep 2

echo "  entware-restore: $(systemctl is-active entware-restore 2>/dev/null)"
echo "  socat-smd7:      $(systemctl is-active socat-smd7 2>/dev/null)"
echo "  socat bridges:   $(systemctl is-active socat-smd7-to-ttyIN2 2>/dev/null)"
echo "  lighttpd:        $(systemctl is-active lighttpd 2>/dev/null)"
echo "  ttyd:            $(systemctl is-active ttyd 2>/dev/null)"

echo ""
echo "=== INSTALLATION COMPLETE ==="
echo "  URL:      https://192.168.1.1:8443"
echo "  Username: admin"
echo "  Password: Asdf@12345"
echo ""
echo "  Accept the browser certificate warning (self-signed cert)."
echo "  All services auto-start on every reboot."
