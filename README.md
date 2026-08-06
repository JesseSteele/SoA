# SoA: Samba on Arch
*A simple script to run a Samba network drive on your LAN using an Arch Linux machine*

So, you found an old PC that just won't play Fortnite or GTA VI. Maybe it's a Mac Mini that won't accept any more updates. Now, you want to use that dinosaur for a drive on your home network—one network disk that computers can quickly copy between without needing the cloud.

You've come to the right repo!

## On the network server machine:
1. Get Arch installed with the drive ready
- Install Arch (or Manjaro, shhhh)
- Set up and format your drive to serve on the network, only these filesystems will work:
  - NTFS (most compatible for Linux, Windows, Apple)
  - FAT32 (legacy compatible; only 4GB files or smaller)
  - ext4 (Linux only, most common and trusted)
  - btrfs (Linux only, supposedly better, yeah right)

2. Find the device or UUID (either will work just fine)

```console
lsblk -f
```
3. Clone this repo and edit the `settings`

```console
git clone https://github.com/JesseSteele/SoA
cd SoA
chmod +x *.sh
nano settings
```

- Must set: `Drive=`
- May change: `SamUser=` & `SamPass=`

4. Install the Samba drive

```console
sudo ./install-samba-lan.sh
```

5. Optionally turn on Wi-Fi

```console
sudo ./enable-samba-wifi.sh
```

6. Done!
- Get a cup of coffee (if your doctor allows)
- Login with your user and password
  - Find the machine or Sam server on the network in files or such
  - Probably use "WORKGROUP" for the domain or workgroup login
- Look at the new network drive and admire your hard work
- Imagine you are at an Internet cafe doing important things

## Technical Info
### `install-samba-lan.sh` does it most of the work for you
- Make sure that have your drive or partition to share all ready
  - It only works for NTFS, FAT32, ext4, and btrfs filesystems
  - Edit `settings` to set your `/dev/sde1` or UUID in the `Drive=` value
    - Get these with `lsblk -f`
- Network user and password login are already set to `samuser` and `sam123`
  - You can change these also in the `settings` file
- This only enables physical LAN with ethernet cables

### `enable-samba-wifi.sh` adds WiFi support
- You must run `install-samba-lan.sh` first
- Just run it and WiFi should allow access
  - This does not change how the server accesses your network
  - This only allows other devices to access the server and network drive using WiFi
- Not running this might be a wise security choice if you don't want neighbors or external access
  - Before running this script, the only way to access the network drive is for a computer or device to physicall plug in to the network with an ethernet cable, making this a quesiton of convenience vs lock-down security
  - Your normal WiFi security would not change, only that the drive allows WiFi access

### `client-booster.md` has some extra commands to polish how the Sam drive appears
- It is unnecessary, but can polishes file explorer use
- It adds a firewall to your local machine with `ufw`, which you could just do yourself
- It is only for Arch Linux machines

### `change-settings.sh`
- This updates user, password, and drive by whatever is in the `settings` file
- Just edit the `settings` file with the credential you want, then run this script to apply your new settings

### More than one drive
- This only sets-up one network drive by default
- You can do more by duplicating the `[Sam]` block in `/etc/samba/smb.conf`
  - If so, change `Sam` and `/srv/public/sam` to the new name you want
- You could see how this is done by poking around inside `install-samba-lan.sh`
  - You will also notice that you don't need any `/etc/fstab` entry at all if you just want to serve a folder right from your Arch Linux machine itself.
    - This script assumes you want a dedicated partition to be served, which is usually the purpose anyway
    - Samba only sees the source partition as just another folder inside `/srv/public/`
    - It is the entry in `/etc/fstab` that made the entire partition look like a folder to Samba, so you could skip `/etc/fstab` and just use an actual folder anyway

```console
sudo nano /etc/samba/smb.conf
```

**`/etc/samba/smb.conf`** second entry example:

```
[Second]
   path = /srv/public/second
   valid users = samuser    # This and everything else stays the same
   writable = yes
   browsable = yes
   guest ok = no
```

```console
sudo nano /etc/fstab
```

**`/etc/fstab`** entry examples:

```
UUID=50M3-NUM89-VERY-LONG /srv/public/second ext4 defaults 0 0 # ext4
UUID=50M3-NUM89 /srv/public/second vfat defaults,iocharset=utf8,umask=000,uid=nobody,gid=nobody 0 0 # FAT32
UUID=50M3NUM89 /srv/public/second ntfs-3g defaults,nls=utf8,umask=000,dmask=000,fmask=000,uid=nobody,gid=nobody 0 0 # NTFS
```

- Note, if using NTFS, we use `ntfs-3g` for the filesystem type in `/etc/fstab` and had to install the `ntfs-3g` package
  - For FAT32, ext4, and btrfs, we don't need those other packages since they have been a part of Linux for a long time already
  - NTFS is built for Windows mainly, so Linux services like Samba might need an additional package since NTFS is readable, but not standard in Linux