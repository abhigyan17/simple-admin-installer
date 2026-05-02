#!/bin/sh

# ttyd wrapper script for Airtel ODU Persistence
# This script is executed on boot by systemd's ttyd.service

# 1. Setup RAMdisk and symlink
if [ ! -d /tmp/opt ]; then
    mkdir -p /tmp/opt
fi

if [ -L /data/opt ] || [ -d /data/opt ]; then
    rm -rf /data/opt
fi
ln -s /tmp/opt /data/opt
if [ ! -L /opt ]; then
    ln -s /data/opt /opt
fi

# 2. Extract Entware backup if empty
if [ ! -f /tmp/opt/bin/opkg ]; then
    if [ -f /data/opt_backup.tar.gz ]; then
        tar xzf /data/opt_backup.tar.gz -C /tmp/
    fi
fi

# 3. Hijack systemd services via /run/systemd/system
mkdir -p /run/systemd/system/
cp /data/simpleadmin/systemd/*.service /run/systemd/system/ 2>/dev/null
cp /data/simplefirewall/systemd/*.service /run/systemd/system/ 2>/dev/null

# 4. Reload systemd and start the hijacked services
systemctl daemon-reload
systemctl start lighttpd 2>/dev/null
systemctl start simplefirewall 2>/dev/null

# 5. Execute the REAL ttyd binary
exec /data/simpleadmin/console/ttyd.bin "$@"
