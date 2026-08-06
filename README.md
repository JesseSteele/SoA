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
- Imagine you are at an Internet cafe doing important things

Once you have everything set

- `install-samba-lan.sh` does it most of the work for you
  - Make sure that have your drive or partition to share all ready
    - It only works for NTFS, FAT32, ext4, and btrfs filesystems
    - Edit `settings` to set your `/dev/sde1` or UUID in the `Drive=` value
      - Get these with `lsblk -f`
  - Network user and password login are already set to `samuser` and `sam123`
    - You can change these also in the `settings` file
  - This only sets-up one network drive
    - You can do more by duplicating the `[Sam]` block in `/etc/samba/smb.conf`
      - If so, don't use `/srv/public`, but put each drive in a subdirectory there
  - This only enables physical LAN with ethernet cables
- `enable-samba-wifi.sh` adds WiFi support after `install-samba-lan.sh`
  - Just run it and WiFi should work
- `client-booster.md` has some extra commands to polish how the Sam drive appears
  - It is unnecessary
  - It is redundant and you may see the network machine twice with two names after running
  - It adds a firewall to your local machine with `ufw`, which you could just do yourself
  - It is only for Arch Linux machines
