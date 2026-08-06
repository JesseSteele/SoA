#!/bin/bash
# Packages
# wsdd: Makes the server appear in Windows 10/11 "Network" view
# avahi: Makes it appear in Linux/macOS/iOS/Android
# ntfs-3g: Required for mounting your NTFS drive /dev/sde1
/usr/bin/pacman -Syy --needed --noconfirm samba ntfs-3g avahi nss-mdns wsdd ufw

# 1. Configuration & Settings
WifiSettingFile="/etc/samba/wifi_access.conf" # If this contains only 'WIFI_ON', then it will serve WiFi, otherwise only LAN
PasswordFile="/etc/samba/sam_password.txt"    # Create a password by putting it as the only text in this file
LoginRefFile="/etc/samba/login.txt"           # Login user and password are stored here

## Defaults
SamUser="samuser"
SamPass="sam123"
Drive="/dev/sde1"  # Can be /dev/sdxX or UUID=SOME-LONG-NUBMER or just the SOME-LONG-NUMBER for the UUID; all will work
FStype="ntfs-3g"
CharSet="nls=utf8"
## Override defaults with settings
if [ -f "settings" ]; then
    /usr/bin/source settings
    ## Resolve the Drive to both device and UUID
    if [[ $Drive =~ ^/dev/ ]]; then
        ### User gave a device path
        DriveDev="$Drive"
        DriveUUID=$(/usr/bin/blkid -s UUID -o value "$DriveDev" 2>/dev/null)

    elif [[ $Drive =~ ^UUID= ]]; then
        ### User gave UUID=xxxx
        DriveUUID="${Drive#UUID=}"
        DriveDev=$(/usr/bin/blkid -U "$DriveUUID" 2>/dev/null)

    elif [[ $Drive =~ ^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$ || $Drive =~ ^[0-9A-Fa-f-]{36}$ ]]; then
        ### User gave a plain UUID
        DriveUUID="$Drive"
        DriveDev=$(/usr/bin/blkid -U "$DriveUUID" 2>/dev/null)

    else
        echo "Error: '$Drive' does not look like a valid device or UUID"
        exit 1
    fi

    ### Final consistency check
    if [[ -z $DriveDev || -z $DriveUUID ]]; then
        echo "Error: Could not resolve both device and UUID for '$Drive'"
        echo "  DriveDev  = '$DriveDev'"
        echo "  DriveUUID = '$DriveUUID'"
        exit 1
    fi

    ## Find the filesystem for the $Drive, either NTFS, FAT32, ext4, or btrfs
    FStype=$(/usr/bin/blkid -s TYPE -o value "$DriveDev" 2>/dev/null)
    ### Check
    if [[ -z $FStype ]]; then
        echo "Error: Could not detect filesystem type for $DriveDev"
        exit 1
    fi
    ### Convert ntfs → ntfs-3g for the mount options in /etc/fstab
    case "$FStype" in
        ntfs|ntfs3)
            FStype="ntfs-3g"
            ;;
    esac

    ## Set mount options in /etc/fstab
    MountOpts="defaults"

    case "$FStype" in
        vfat)
            MountOpts="$MountOpts,iocharset=utf8,umask=000,uid=nobody,gid=nobody"
            ;;
        ntfs-3g)
            MountOpts="$MountOpts,nls=utf8,umask=000,uid=nobody,gid=nobody"
            ;;
        ext4)
            # Native Linux filesystem – minimal options
            MountOpts="$MountOpts"
            # Optional: MountOpts="$MountOpts,noatime"
            ;;
        btrfs)
            # Native Linux filesystem – minimal options
            MountOpts="$MountOpts"
            # Optional: MountOpts="$MountOpts,noatime,compress=zstd"
            ;;
        *)
            echo "Error: Unsupported filesystem type: $FStype"
            exit 1
            ;;
    esac
fi


# Initialize files if they don't exist
[ ! -f "$WifiSettingFile" ] && /usr/bin/echo "WIFI_OFF" > "$WifiSettingFile"
[ ! -f "$PasswordFile" ] && /usr/bin/echo $SamPass > "$PasswordFile"

# Logic: Must be exactly "WIFI_ON" to enable WiFi
WifiRaw=$(/usr/bin/cat "$WifiSettingFile" | /usr/bin/tr -d '[:space:]')
if [ "$WifiRaw" == "WIFI_ON" ]; then
    WifiStatus="ENABLED"
else
    WifiStatus="DISABLED"
fi

PlainPass=$(/usr/bin/cat "$PasswordFile" | /usr/bin/tr -d '[:space:]')

# Create human-readable login reference
/usr/bin/echo -e "Username: $SamUser\nPassword: $PlainPass" > "$LoginRefFile"

# Identify Ethernet interface
EthIface=$(/usr/bin/ip -o link show | /usr/bin/awk -F': ' '$2 ~ /^e/ {print $2; exit}')
Loopback="lo"

# 2. Install required packages
/usr/bin/pacman -Syy --needed --noconfirm samba ntfs-3g avahi nss-mdns wsdd ufw

# 3. Mount Drive
/usr/bin/mkdir -p /srv/public
## Mount drive as the /srv/public drive
if ! /usr/bin/grep -q "/srv/public" /etc/fstab; then
    /usr/bin/echo "# Samba network Drive" >> /etc/fstab
    /usr/bin/echo "UUID=$DriveUUID /srv/public $FStype $MountOpts 0 0" >> /etc/fstab
#   /usr/bin/echo "/dev/sde1 /srv/public ntfs-3g defaults,nls=utf8,umask=000,dmask=000,fmask=000,uid=nobody,gid=nobody 0 0" >> /etc/fstab  # /dev/sd... method
#   /usr/bin/echo "UUID=50M3-NUM89 /srv/public ntfs-3g defaults,nls=utf8,umask=000,dmask=000,fmask=000,uid=nobody,gid=nobody 0 0" >> /etc/fstab  # UUID method
#   /usr/bin/echo "UUID=50M3-NUM89 /srv/public vfat defaults,iocharset=utf8,umask=000,uid=nobody,gid=nobody 0 0" >> /etc/fstab  # UUID method for FAT32
#   /usr/bin/echo "/dev/sde1 /srv/public vfat defaults,iocharset=utf8,umask=000,uid=nobody,gid=nobody 0 0" >> /etc/fstab  # /dev/sd... method for FAT32
fi
/usr/bin/mount -a
## Ownership
/usr/bin/chown -R nobody:nobody /srv/public
/usr/bin/chmod 777 /srv/public

# 4. User and Password Management
## Add the Linux user
if ! /usr/bin/id "$SamUser" &>/dev/null; then
    /usr/bin/useradd -M -s /usr/bin/nologin "$SamUser"
fi
## Ensure smb is running before setting password
systemctl start smb 2>/dev/null
## Set password in Samba non-interactively
printf '%s\n%s\n' "$PlainPass" "$PlainPass" | smbpasswd -s -a "$SamUser"
 ## Make sure the account is enabled
smbpasswd -e "$SamUser" >/dev/null 2>&1

# 5. Configure Samba
BindLogic=""
if [ "$WifiStatus" == "DISABLED" ] && [ -n "$EthIface" ]; then
    BindLogic="interfaces = $Loopback $EthIface
   bind interfaces only = yes"
fi

/usr/bin/cat <<EOF > /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   server string = Sam Drive
   netbios name = SAM
   security = user
   map to guest = Never
   server min protocol = SMB2
   $BindLogic

[Sam]
   path = /srv/public
   valid users = $SamUser
   writable = yes
   browsable = yes
   guest ok = no
EOF

# 6. Configure Avahi (Discovery)
AvahiIface=""
[ "$WifiStatus" == "DISABLED" ] && [ -n "$EthIface" ] && AvahiIface="allow-interfaces=$EthIface"
/usr/bin/sed -i "s/^#\?allow-interfaces=.*/$AvahiIface/" /etc/avahi/avahi-daemon.conf

/usr/bin/cat <<EOF > /etc/avahi/services/samba.service
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">Sam</name>
  <service>
    <type>_smb._tcp</type>
    <port>445</port>
  </service>
</service-group>
EOF

# 7. Windows Discovery (wsdd) Override
if [ "$WifiStatus" == "DISABLED" ] && [ -n "$EthIface" ]; then
    /usr/bin/mkdir -p /etc/systemd/system/wsdd.service.d
    /usr/bin/echo -e "[Service]\nExecStart=\nExecStart=/usr/bin/wsdd --shortlog -i $EthIface" > /etc/systemd/system/wsdd.service.d/override.conf
else
    /usr/bin/rm -f /etc/systemd/system/wsdd.service.d/override.conf
fi
/usr/bin/systemctl daemon-reload

# 8. Name Resolution & Firewall
/usr/bin/sed -i 's/hosts: \(.*\)resolve/hosts: \1mdns_minimal [NOTFOUND=return] resolve/' /etc/nsswitch.conf
/usr/bin/ufw allow 137,138/udp && /usr/bin/ufw allow 139,445/tcp && /usr/bin/ufw allow 5353/udp
/usr/bin/ufw allow 3702/udp && /usr/bin/ufw allow 5357,5358/tcp
/usr/bin/ufw --force enable

# 9. Start/Restart Services
/usr/bin/systemctl enable --now smb nmb avahi-daemon wsdd ufw
/usr/bin/systemctl restart smb nmb avahi-daemon wsdd

/usr/bin/echo "------------------------------------------------------------------"
/usr/bin/echo "SUCCESS! 'Sam' is active. WiFi Access: $WifiStatus"
/usr/bin/echo "------------------------------------------------------------------"
/usr/bin/echo "CREDENTIALS SAVED TO: $LoginRefFile"
/usr/bin/echo "DOMAIN: \"WORKGROUP\" (usually leave as-is)"
/usr/bin/echo "------------------------------------------------------------------"
/usr/bin/echo "WINDOWS: Open File Explorer -> Network. 'SAM' will appear."
/usr/bin/echo "LINUX: Open File Manager -> Other Locations -> 'Sam' or 'sam.local'."
/usr/bin/echo "iOS: Open Files App -> '...' -> Connect to Server -> 'sam.local'."
/usr/bin/echo "ANDROID: Use 'Solid Explorer' or 'FX File Explorer' to Scan/Add LAN."
/usr/bin/echo "------------------------------------------------------------------"

