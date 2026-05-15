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

You can test the install script in a VM using Vagrant and libvirt.

### Host dependencies (Arch)

```bash
# Core packages
sudo pacman -S --needed \
    vagrant libvirt qemu-base virt-viewer virt-install \
    dnsmasq iptables-nft \
    xdotool python \
    libxslt libxml2 pkgconf base-devel

# libvirt daemon + group membership (log out/in after the usermod)
sudo systemctl enable --now libvirtd.service
sudo usermod -aG libvirt "$USER"
```

Then install the `vagrant-libvirt` plugin. The plain `vagrant plugin install vagrant-libvirt` often fails on Arch because vagrant ships its own embedded ruby. Use this incantation instead:

```bash
CONFIGURE_ARGS='with-ldflags=-L/opt/vagrant/embedded/lib with-libvirt-include=/usr/include/libvirt with-libvirt-lib=/usr/lib' \
PKG_CONFIG_PATH=/opt/vagrant/embedded/lib/pkgconfig \
vagrant plugin install vagrant-libvirt
```

Verify with `vagrant plugin list` — you should see `vagrant-libvirt`.

### Running the test

```bash
cd arch/install/testing
./test.sh
```

`test.sh` will:
1. `vagrant up --provider=libvirt` (downloads the Arch ISO on first run).
2. Open `virt-viewer` on the VM console.
3. Start an HTTP server in `arch/install/` and auto-type a `curl` command into the VM window via `xdotool` that fetches `install-arch.sh` and `configure-chroot.sh` into `/tmp/`.

In the VM, run:

```bash
/tmp/install-arch.sh
```

When you're done, `Ctrl+C` the HTTP server and `vagrant destroy` to clean up.

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


