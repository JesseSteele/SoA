# Redundant "help"
*These could clean-up an Arch Linux client machine's interaction with the server, but it would be redundant*

```console
sudo /usr/bin/pacman -Syy --needed --noconfirm gvfs-smb avahi nss-mdns ufw && \
sudo /usr/bin/sed -i 's/hosts: \(.*\)resolve/hosts: \1mdns_minimal [NOTFOUND=return] resolve/' /etc/nsswitch.conf && \
sudo /usr/bin/ufw allow 5353/udp && sudo /usr/bin/ufw --force enable && \
sudo /usr/bin/systemctl enable --now avahi-daemon ufw
```
