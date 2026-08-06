#!/bin/bash
# update-samba-credentials.sh
# Updates Samba user, password, and drive based on the settings file.
# - Rewrites all "valid users =" lines to the single user from settings
# - Sets the Samba password
# - Updates the drive mount if needed
# - Does NOT delete old Linux users

set -e

SETTINGS_FILE="./settings"

if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "Error: settings file not found at $SETTINGS_FILE"
    exit 1
fi

# Load settings
source "$SETTINGS_FILE"

# Sanity checks
if [[ -z "$SamUser" || -z "$SamPass" || -z "$Drive" ]]; then
    echo "Error: SamUser, SamPass, and Drive must be set in settings"
    exit 1
fi

echo "→ Using user: $SamUser"
echo "→ Using drive: $Drive"

#######################################
# 1. Resolve Drive → Device + UUID + FS
#######################################

DriveDev=""
DriveUUID=""

if [[ $Drive =~ ^/dev/ ]]; then
    DriveDev="$Drive"
    DriveUUID=$(/usr/bin/blkid -s UUID -o value "$DriveDev" 2>/dev/null)
elif [[ $Drive =~ ^UUID= ]]; then
    DriveUUID="${Drive#UUID=}"
    DriveDev=$(/usr/bin/blkid -U "$DriveUUID" 2>/dev/null)
elif [[ $Drive =~ ^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$ || $Drive =~ ^[0-9A-Fa-f-]{36}$ ]]; then
    DriveUUID="$Drive"
    DriveDev=$(/usr/bin/blkid -U "$DriveUUID" 2>/dev/null)
else
    echo "Error: '$Drive' is not a valid device or UUID"
    exit 1
fi

if [[ -z $DriveDev || -z $DriveUUID ]]; then
    echo "Error: Could not resolve both device and UUID"
    echo "  DriveDev  = '$DriveDev'"
    echo "  DriveUUID = '$DriveUUID'"
    exit 1
fi

FStype=$(/usr/bin/blkid -s TYPE -o value "$DriveDev" 2>/dev/null)
if [[ -z $FStype ]]; then
    echo "Error: Could not detect filesystem type for $DriveDev"
    exit 1
fi

case "$FStype" in
    ntfs|ntfs3) FStype="ntfs-3g" ;;
esac

MountOpts="defaults"
case "$FStype" in
    vfat)
        MountOpts="$MountOpts,iocharset=utf8,umask=000,uid=nobody,gid=nobody"
        ;;
    ntfs-3g)
        MountOpts="$MountOpts,nls=utf8,umask=000,uid=nobody,gid=nobody"
        ;;
    ext4|btrfs)
        : # keep defaults
        ;;
    *)
        echo "Error: Unsupported filesystem: $FStype"
        exit 1
        ;;
esac

#######################################
# 2. Update all "valid users =" lines
#######################################

if [[ -f /etc/samba/smb.conf ]]; then
    echo "→ Updating all 'valid users =' lines to: $SamUser"
    /usr/bin/sed -i "s/^[[:space:]]*valid users[[:space:]]*=.*/   valid users = $SamUser/" /etc/samba/smb.conf
else
    echo "Warning: /etc/samba/smb.conf not found"
fi

#######################################
# 3. Ensure Linux user exists + set Samba password
#######################################

if ! id "$SamUser" &>/dev/null; then
    echo "→ Creating Linux user: $SamUser"
    /usr/bin/useradd -M -s /usr/bin/nologin "$SamUser"
fi

echo "→ Setting Samba password for $SamUser"
/usr/bin/systemctl start smb 2>/dev/null || true
/usr/bin/printf '%s\n%s\n' "$SamPass" "$SamPass" | /usr/bin/smbpasswd -s -a "$SamUser"
/usr/bin/smbpasswd -e "$SamUser" >/dev/null 2>&1 || true

#######################################
# 4. Update fstab entry for /srv/public (optional but useful)
#######################################

echo "→ Updating /etc/fstab entry for /srv/public"

# Remove any existing /srv/public line
/usr/bin/sed -i '\#/srv/public#d' /etc/fstab

# Add the new one
echo "UUID=$DriveUUID  /srv/public  $FStype  $MountOpts  0  0" >> /etc/fstab

/usr/bin/mkdir -p /srv/public
/usr/bin/mount -a

/usr/bin/chown -R nobody:nobody /srv/public
/usr/bin/chmod 777 /srv/public

#######################################
# 5. Update login reference file
#######################################

echo -e "Username: $SamUser\nPassword: $SamPass" > /etc/samba/login.txt

#######################################
# 6. Restart services
#######################################

/usr/bin/systemctl restart smb nmb

echo ""
echo "--------------------------------------------------"
echo "SUCCESS! Credentials and drive updated."
echo "  User     : $SamUser"
echo "  Password : $SamPass"
echo "  Drive    : $DriveDev (UUID=$DriveUUID)"
echo "  FS Type  : $FStype"
echo "--------------------------------------------------"