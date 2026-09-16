#!/bin/bash
# Rescue script for post-hardware-swap boot recovery.
#
# When to run: motherboard/CPU swap on a box installed with install-arch.sh.
# What breaks:
#   1. UEFI NVRAM boot entry lives on the old motherboard's firmware — the new
#      board has no idea where GRUB is. Fixed by re-running `grub-install`,
#      which calls `efibootmgr` to write a fresh NVRAM entry.
#   2. initramfs was built with the `autodetect` mkinitcpio hook, so it only
#      contains the KMS driver for the old iGPU/GPU. New CPU = new iGPU =
#      screen goes black after GRUB. Fixed by `mkinitcpio -P` which rebuilds
#      against the currently-running hardware.
#
# Boot the Arch live USB, get network if needed, then run this script.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

prompt() {
	local message="$1" response
	echo -en "${YELLOW}[PROMPT]${NC} $message " >&2
	read -r response
	echo "$response"
}

prompt_confirm() {
	local message="$1" response
	while true; do
		echo -en "${YELLOW}[CONFIRM]${NC} $message (y/n): "
		read -r response
		case "$response" in
		[yY]|[yY][eE][sS]) return 0 ;;
		[nN]|[nN][oO]) return 1 ;;
		*) echo "Please answer yes or no." ;;
		esac
	done
}

preflight() {
	[ "$EUID" -eq 0 ] || error "Must run as root"
	[ -d /sys/firmware/efi ] || error "Live USB is not booted in UEFI mode — reboot the USB in UEFI mode"
	command -v arch-chroot >/dev/null || error "arch-chroot not found — are you on the Arch live ISO?"
}

# Ask which disk holds the existing install, and derive partition names.
# Sets: EFI_PART, ROOT_PART
pick_disk() {
	info "Available disks:"
	lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E 'disk$' || true

	local disk
	disk=$(prompt "Which disk has the existing Arch install? (e.g., /dev/nvme0n1, /dev/sda):")
	[ -b "$disk" ] || error "Not a block device: $disk"

	info "Partitions on $disk:"
	lsblk "$disk"

	local part_prefix
	if [[ "$disk" == *"nvme"* ]]; then
		part_prefix="${disk}p"
	else
		part_prefix="${disk}"
	fi

	# install-arch.sh always lays out ESP as p1 and root as p2.
	EFI_PART="${part_prefix}1"
	ROOT_PART="${part_prefix}2"

	[ -b "$EFI_PART" ] || error "EFI partition not found at $EFI_PART"
	[ -b "$ROOT_PART" ] || error "Root partition not found at $ROOT_PART"

	info "Using EFI=$EFI_PART, ROOT=$ROOT_PART"
}

# If root is LUKS, prompt to unlock. Sets ROOT_DEV to the mount source.
open_luks_if_needed() {
	if cryptsetup isLuks "$ROOT_PART" 2>/dev/null; then
		info "$ROOT_PART is LUKS-encrypted, unlocking..."
		cryptsetup open "$ROOT_PART" cryptroot
		ROOT_DEV=/dev/mapper/cryptroot
	else
		ROOT_DEV="$ROOT_PART"
	fi
}

# Mount root (Btrfs @ subvol if present, else plain), then ESP at /mnt/boot.
mount_target() {
	info "Mounting $ROOT_DEV -> /mnt..."
	# Try Btrfs @ subvol first (install-arch.sh's default layout); fall back to
	# a plain mount for other filesystems.
	if ! mount -o subvol=@ "$ROOT_DEV" /mnt 2>/dev/null; then
		mount "$ROOT_DEV" /mnt
	fi

	info "Mounting $EFI_PART -> /mnt/boot..."
	mount "$EFI_PART" /mnt/boot
}

# Run grub-install (writes NVRAM entry via efibootmgr) and mkinitcpio -P
# (rebuilds initramfs against the live hardware) inside the target system.
repair_in_chroot() {
	info "Current NVRAM entries (before):"
	efibootmgr || true

	info "Entering chroot to reinstall GRUB and rebuild initramfs..."
	arch-chroot /mnt /bin/bash <<'CHROOT'
set -euo pipefail
echo "[chroot] grub-install..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
echo "[chroot] grub-mkconfig..."
grub-mkconfig -o /boot/grub/grub.cfg
echo "[chroot] mkinitcpio -P..."
mkinitcpio -P
CHROOT

	info "NVRAM entries (after):"
	efibootmgr
}

cleanup() {
	info "Unmounting..."
	umount -R /mnt 2>/dev/null || true
	[ -e /dev/mapper/cryptroot ] && cryptsetup close cryptroot 2>/dev/null || true
}

main() {
	preflight
	pick_disk
	open_luks_if_needed
	mount_target
	repair_in_chroot
	cleanup

	info "Done. Remove the USB and reboot."
	if prompt_confirm "Reboot now?"; then
		reboot
	fi
}

main "$@"
