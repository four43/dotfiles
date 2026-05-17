# Arch Testing

Installs the latest Arch OS with KDE Plasma desktop environment using Vagrant over libvirt.

## Installing

This contains an install script I've written that's based on the [Arch wiki install](https://wiki.archlinux.org/title/Installation_guide) guide, with the following changes:

* Disk Configuration:
  * Separate partition for `/boot` (512MB, FAT32)
  * [System encryption](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system) with LUKS (similar to how Ubuntu does it)
  * Use LVM for partitioning user space mounts:
    * `/` (root) - 50GB
    * `/home` - 20GB
    * `/var` - 100GB
    * `/tmp` - 32GB
* Enable [timeshift](https://wiki.archlinux.org/title/Timeshift) for system snapshots

## Testing in a VM

A libvirt VM that boots the Arch live ISO, lets you run the installer manually inside it, then either reboots into the installed system or tears down for a clean retry. No Vagrant — just `virt-install` + `virsh`.

### First-time host setup

```bash
cd arch/install/testing
./host-install.sh
```

Idempotent. Installs packages (libvirt, qemu-desktop, virt-viewer, virt-install, ydotool, libosinfo, dnsmasq, iptables-nft), enables `libvirtd`, switches libvirt to the native nftables firewall backend, installs a libvirt network hook for Docker coexistence, adds you to the `libvirt` group, and grants `libvirt-qemu` traverse on `$HOME` via ACL.

Safe to re-run any time. The network hook is overwritten on every run, so `host-install.sh` is the single source of truth.

#### Docker + libvirt firewall coexistence

If Docker is installed on the same host, two collisions need handling:

1. **libvirt's iptables NAT rules silently fail to install** because Docker has taken over the `iptables-nft` compatibility layer. `host-install.sh` sets `firewall_backend = "nftables"` in `/etc/libvirt/network.conf` so libvirt writes its rules to its own `inet libvirt_network` table (visible via `sudo nft list table inet libvirt_network`).

2. **Docker's default-DROP on the host `FORWARD` chain blocks libvirt VM traffic** even with NAT correctly in place — the VM gets DHCP, can reach `192.168.122.1`, but can't forward to the internet. There is no architectural separation here: Linux has a single global `FORWARD` chain that every daemon participates in. Docker's recommended escape hatch is the `DOCKER-USER` chain — rules added there run before Docker's defaults and Docker preserves them across daemon restarts.

`host-install.sh` installs `/etc/libvirt/hooks/network` to handle this automatically. The hook fires whenever libvirt's default network starts, and adds:

```
iptables -I DOCKER-USER -i virbr0 -j ACCEPT
iptables -I DOCKER-USER -o virbr0 -j ACCEPT
```

It removes them when the network stops. So:

- **Host reboot:** Docker starts, libvirtd starts, the default network auto-starts (because `host-install.sh` set `net-autostart`), hook fires, rules added. No manual intervention.
- **Docker daemon restart:** Docker preserves `DOCKER-USER` rules across restarts (documented behavior). Nothing breaks.
- **`host-install.sh` re-run on an already-set-up host:** rules are re-checked and added if missing (idempotent), and the hook script is overwritten to match the version in this script.

The only edge case that requires intervention: if `libvirtd` starts *before* `dockerd` at boot, the hook fires while the `DOCKER-USER` chain doesn't exist yet and exits silently. Re-run `./host-install.sh` once after Docker is up to apply the rules. On a typical desktop with both services on autostart, Docker comes up first and this isn't an issue.

#### After first run

If `host-install.sh` reports it added you to the `libvirt` group, **log out of your desktop session and back in** before continuing. Otherwise every `virsh` call triggers a KDE polkit auth popup.

### Running the test

```bash
./test.sh
```

What it does, in order:
1. Starts the `ydotoold` daemon (one sudo prompt per shell session — it needs root to write to `/dev/uinput`; the socket gets chowned to you).
2. Brings up libvirt's `default` NAT network if it isn't already active.
3. Downloads `archlinux-2026.05.01-x86_64.iso` into this directory if missing.
4. Defines (or starts) an `arch-install-test` VM with virt-install: 4GB RAM, 2 vCPU, Q35 + UEFI, 40 GB virtio qcow2 disk, SPICE display with qxl video, virtio network on the default bridge.
5. Opens `virt-viewer` on the VM console.
6. Starts an HTTP server in `arch/install/` so both `install-arch.sh` and `configure-chroot.sh` are reachable.
7. Waits for you to press Enter (do that once the VM has reached the `root@archiso` prompt).
8. After a 5-second countdown, ydotool types the curl command into whatever window has focus — make sure that's the virt-viewer window. Enter is NOT sent automatically; press it yourself inside the VM after you see the host print `Serving HTTP...`.

In the VM:

```bash
/tmp/install-arch.sh
```

When you're done, `Ctrl+C` the HTTP server on the host, then `./cleanup.sh` to destroy + undefine the VM (with its NVRAM and 40 GB disk).

## Creating a Bootable USB Drive (Debian host)

### Write ISO to Flash Drive

1. Download the latest Arch Linux ISO:

```bash
wget https://fastly.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso
```

1. Identify your USB drive:

```bash
lsblk
# Look for your USB drive (e.g., /dev/sdb), probably the only one that's a devices that's < 1TB these days.
```

1. Write the ISO to the USB drive:

```bash
# Set your USB drive device (e.g., /dev/sda, /dev/sdb)
PARTITION=/dev/sdX

# Get the ISO filename
ISO_FILE=$(ls archlinux-*x86_64.iso)
sudo dd if=$ISO_FILE of=$PARTITION bs=4M status=progress oflag=sync
```

⚠️ **WARNING**: Double-check the device name! This will erase all data on the target drive.

### Add Install Script to USB Drive

After writing the ISO, create a data partition for your scripts:

1. Create a new partition in the unused space:

```bash
# Create new partition automatically
printf "n\np\n\n\n\nw\n" | sudo fdisk $PARTITION

# Wait for partition table to update
sudo lsblk $PARTITION
```

1. Format the new partition and copy the script:

```bash
# Format as ext4 (partition 3 is typically the new data partition)
sudo mkfs.ext4 -L ARCHSCRIPTS ${PARTITION}3

# Mount, copy script, and unmount
sudo mkdir -p /mnt/archusb
sudo mount ${PARTITION}3 /mnt/archusb
sudo cp install-arch.sh /mnt/archusb/
sudo chmod +x /mnt/archusb/install-arch.sh
sudo cp -r ~/.ssh /mnt/smiller/
sudo umount /mnt/archusb
```

### Using the Script After Booting

1. Boot from the USB drive
2. Once in the Arch live environment, mount the scripts partition:

```bash
mkdir /usb
mount /dev/disk/by-label/ARCHSCRIPTS /usb
```

1. Run the install script:

⚠️ **NOTE**: Use `iwctl` to connect to Wi-Fi if needed. `iwctl<enter>` then `station wlan0 connect YOUR_SSID`.

```bash
bash /mnt/usb/install-arch.sh
```


## Tips

### BTRFS Subvolumes

```bash
# Check current usage against quotas

sudo btrfs qgroup show /

# Change a quota limit (e.g., increase /var to 40GB)

sudo btrfs qgroup limit 40G /@var

# Remove a quota limit (make unlimited)

sudo btrfs qgroup limit none /@var

# Disable quotas entirely (if needed)

sudo btrfs quota disable /
```

## TODO

```
pacman -S plasma-meta sddm konsole dolphin
systemctl enable sddm.service

# Timeshift
pacman -S timeshift
# timeshift-gtk
```


