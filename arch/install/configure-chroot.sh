#!/bin/bash
# Configure a freshly installed Arch system from within arch-chroot.
# Expects the following environment variables to be set by the caller:
#   TIMEZONE, LOCALE, KEYMAP, HOSTNAME, LUKS_PART, HAS_NVIDIA,
#   ENCRYPT, TPM2_AUTOUNLOCK, ROLE

set -euo pipefail

: "${TIMEZONE:?TIMEZONE must be set}"
: "${LOCALE:?LOCALE must be set}"
: "${KEYMAP:?KEYMAP must be set}"
: "${HOSTNAME:?HOSTNAME must be set}"
: "${LUKS_PART:?LUKS_PART must be set}"
: "${HAS_NVIDIA:?HAS_NVIDIA must be set}"
: "${ENCRYPT:?ENCRYPT must be set}"
: "${TPM2_AUTOUNLOCK:?TPM2_AUTOUNLOCK must be set}"
: "${ROLE:?ROLE must be set}"

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

# Configure mkinitcpio for Btrfs (plus encryption hooks when applicable):
# - No encryption: drop the `encrypt` hook entirely (plaintext root).
# - LUKS, no TPM2: legacy `udev` + `encrypt` hooks (passphrase each boot).
# - LUKS + TPM2:   `systemd` + `sd-encrypt` hooks, which consume TPM2 tokens
#                  stored in the LUKS header by systemd-cryptenroll.
if [ "$ENCRYPT" != "true" ]; then
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/' /etc/mkinitcpio.conf
elif [ "$TPM2_AUTOUNLOCK" = "true" ]; then
    sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
else
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
fi

# Regenerate initramfs
mkinitcpio -P

# Set root password. Loop on failure (mismatched confirmation, too short, etc.)
# so a typo doesn't kill the entire install — `set -e` would otherwise bail.
echo "Setting root password..."
until passwd; do
	echo "Password not set. Try again."
done

# Configure GRUB cmdline for Btrfs root.
# - No encryption: point root= directly at the Btrfs partition by UUID.
# - sd-encrypt:    uses `rd.luks.name=` to map the LUKS device.
# - legacy encrypt:uses `cryptdevice=` to map the LUKS device.
ROOT_UUID=$(blkid -s UUID -o value "$LUKS_PART")
if [ "$ENCRYPT" != "true" ]; then
    CMDLINE="root=UUID=${ROOT_UUID} rootflags=subvol=@"
elif [ "$TPM2_AUTOUNLOCK" = "true" ]; then
    CMDLINE="rd.luks.name=${ROOT_UUID}=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@"
else
    CMDLINE="cryptdevice=UUID=${ROOT_UUID}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@"
fi
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"${CMDLINE}\"|" /etc/default/grub

# Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Route NetworkManager DNS through systemd-resolved.
# Keeps Docker/VPN clients from losing DNS when the active connection changes.
# NOTE: the /etc/resolv.conf -> stub-resolv.conf symlink is created by the
# host-side installer AFTER arch-chroot exits — arch-chroot bind-mounts
# /etc/resolv.conf, so we cannot manipulate it from inside the chroot.
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/dns.conf <<'EOF'
[main]
dns=systemd-resolved
EOF

echo "Optimizing mirrorlist for the United States..." >&2
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

# Enable services common to all roles.
systemctl enable NetworkManager
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
systemctl enable sshd
# cron is used by timeshift to schedule Btrfs snapshots
systemctl enable cronie
# Weekly mirror refresh
systemctl enable reflector.timer
# Docker (socket-activated, plus the daemon for boot-time autostart)
systemctl enable docker.socket
systemctl enable docker.service

# Workstation-only services: display manager and bluetooth.
if [ "$ROLE" = "workstation" ]; then
    systemctl enable sddm
    systemctl enable bluetooth
fi

# Enable periodic TRIM for SSD optimization
# fstrim.timer runs weekly to optimize SSD performance
systemctl enable fstrim.timer

# User creation is handled by configure-user.sh (a separate, personal-overrides
# script run after this one), which also enables wheel sudo. Anyone using these
# scripts without configure-user.sh can `useradd` manually after first boot.

# Enroll the LUKS key into the TPM2 so the disk auto-unlocks on this hardware.
# PCR 7 binds to Secure Boot state: kernel updates keep working; toggling
# Secure Boot or firmware updates may invalidate the binding (fall back to
# the passphrase and re-run this command to re-enroll).
if [ "$TPM2_AUTOUNLOCK" = "true" ]; then
    echo ""
    echo "============================================"
    echo "Enrolling LUKS key into TPM2 (PCR 7)..."
    echo "You will be prompted for the LUKS passphrase set during partitioning."
    echo "============================================"
    systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$LUKS_PART"
    echo "TPM2 enrollment complete. The disk will auto-unlock on this machine."
fi

echo "Base configuration complete!"
