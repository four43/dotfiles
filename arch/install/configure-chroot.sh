#!/bin/bash
# Configure a freshly installed Arch system from within arch-chroot.
# Expects the following environment variables to be set by the caller:
#   TIMEZONE, LOCALE, KEYMAP, HOSTNAME, LUKS_PART, HAS_NVIDIA

set -euo pipefail

: "${TIMEZONE:?TIMEZONE must be set}"
: "${LOCALE:?LOCALE must be set}"
: "${KEYMAP:?KEYMAP must be set}"
: "${HOSTNAME:?HOSTNAME must be set}"
: "${LUKS_PART:?LUKS_PART must be set}"
: "${HAS_NVIDIA:?HAS_NVIDIA must be set}"

# Set timezone
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

# Configure locale
sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Set keyboard layout
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname

# Blacklist nouveau if NVIDIA drivers are installed
if [ "$HAS_NVIDIA" = "true" ]; then
    echo "Blacklisting nouveau drivers..."
    mkdir -p /etc/modprobe.d
    cat > /etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
fi

# Configure mkinitcpio for encryption and Btrfs
# Standard hooks for LUKS on a partition (per Arch wiki)
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf

# Regenerate initramfs
mkinitcpio -P

# Set root password
echo "Setting root password..."
passwd

# Configure GRUB for encrypted boot with Btrfs
LUKS_UUID=$(blkid -s UUID -o value "$LUKS_PART")
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@\"|" /etc/default/grub

# Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Route NetworkManager DNS through systemd-resolved.
# Keeps Docker/VPN clients from losing DNS when the active connection changes.
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/dns.conf <<'EOF'
[main]
dns=systemd-resolved
EOF
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Seed an optimized mirrorlist and keep it fresh via reflector.timer
cat > /etc/xdg/reflector/reflector.conf <<'EOF'
--save /etc/pacman.d/mirrorlist
--protocol https
--country 'United States'
--latest 20
--sort rate
EOF
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector --country 'United States' --protocol https --latest 20 --sort rate \
	--save /etc/pacman.d/mirrorlist

# Enable services
systemctl enable bluetooth
systemctl enable NetworkManager
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
systemctl enable sshd
systemctl enable sddm
# cron is used by timeshift to schedule Btrfs snapshots
systemctl enable cronie
# Weekly mirror refresh
systemctl enable reflector.timer

# Enable periodic TRIM for SSD optimization
# fstrim.timer runs weekly to optimize SSD performance
systemctl enable fstrim.timer

# Create a non-root user (optional)
echo ""
echo "Would you like to create a non-root user? (recommended)"
read -p "Enter username (or press Enter to skip): " USERNAME
if [ -n "$USERNAME" ]; then
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "Setting password for $USERNAME..."
    passwd "$USERNAME"

    # Allow wheel group to use sudo
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
fi

echo "Base configuration complete!"
