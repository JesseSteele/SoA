#!/bin/bash

echo "Enabling Samba on all interfaces (including WiFi)..."

# 1. Remove interface binding from smb.conf
if [ -f /etc/samba/smb.conf ]; then
    # Remove any existing interfaces / bind lines
    sed -i '/^[[:space:]]*interfaces[[:space:]]*=/d' /etc/samba/smb.conf
    sed -i '/^[[:space:]]*bind interfaces only[[:space:]]*=/d' /etc/samba/smb.conf
    echo "→ Removed interface restrictions from smb.conf"
fi

# 2. Remove wsdd interface restriction (if it exists)
if [ -f /etc/systemd/system/wsdd.service.d/override.conf ]; then
    rm -f /etc/systemd/system/wsdd.service.d/override.conf
    systemctl daemon-reload
    echo "→ Removed wsdd interface restriction"
fi

# 3. Reset Avahi to allow all interfaces
if [ -f /etc/avahi/avahi-daemon.conf ]; then
    sed -i 's/^allow-interfaces=.*/#allow-interfaces=/' /etc/avahi/avahi-daemon.conf
    sed -i 's/^#allow-interfaces=$/#allow-interfaces=/' /etc/avahi/avahi-daemon.conf
    echo "→ Reset Avahi to allow all interfaces"
fi

# 4. Restart services
systemctl restart smb nmb avahi-daemon wsdd

echo ""
echo "Done! Samba is now available on both Ethernet and WiFi."
echo "Test with: smbclient //$(hostname -I | awk '{print $1}')/Sam -U samuser"
