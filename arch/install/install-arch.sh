#!/bin/bash
# Arch Linux Installation Script with LUKS Encryption and Btrfs
# Based on: https://wiki.archlinux.org/title/Installation_guide
#           https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system
#           https://wiki.archlinux.org/title/Btrfs

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
info() {
	echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
	echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
	echo -e "${RED}[ERROR]${NC} $1"
	exit 1
}

prompt() {
	local message="$1"
	local response
	echo -en "${YELLOW}[PROMPT]${NC} $message " >&2
	read -r response
	echo "$response"
}

prompt_confirm() {
	local message="$1"
	local response
	while true; do
		echo -en "${YELLOW}[CONFIRM]${NC} $message (y/n): "
		read -r response
		case "$response" in
		[yY] | [yY][eE][sS]) return 0 ;;
		[nN] | [nN][oO]) return 1 ;;
		*) echo "Please answer yes or no." ;;
		esac
	done
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
	error "This script must be run as root"
fi

# Check if running in UEFI mode
info "Verifying boot mode..."
if [ ! -d /sys/firmware/efi ]; then
	error "System is not booted in UEFI mode. This script requires UEFI."
fi

info "System is booted in UEFI mode"

# Verify internet connection
info "Verifying internet connection..."
if ! curl -s --connect-timeout 5 https://www.google.com >/dev/null 2>&1; then
	error "No internet connection. Please connect to the internet and try again."
fi
info "Internet connection verified"

# Update system clock
info "Updating system clock..."
timedatectl set-ntp true
sleep 2
timedatectl status

# List available disks
info "Available disks:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "^(sd|nvme|vd)"

# Get target disk
DISK=$(prompt "Enter the target disk (e.g., /dev/sda or /dev/nvme0n1):")
if [ ! -b "$DISK" ]; then
	error "Disk $DISK does not exist"
fi

warn "WARNING: All data on $DISK will be destroyed!"
if ! prompt_confirm "Are you sure you want to continue?"; then
	error "Installation cancelled by user"
fi

# Get hostname
HOSTNAME=$(prompt "Enter hostname for this system (default: arch-testing):")
HOSTNAME=${HOSTNAME:-arch-testing}

# Get timezone
info "Example timezones: America/New_York, Europe/London, Asia/Tokyo"
TIMEZONE=$(prompt "Enter timezone (default: America/Chicago):")
TIMEZONE=${TIMEZONE:-America/Chicago}
if [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
	error "Invalid timezone: $TIMEZONE"
fi

# Get locale
info "Common locales: en_US.UTF-8, en_GB.UTF-8, de_DE.UTF-8"
LOCALE=$(prompt "Enter locale (default: en_US.UTF-8):")
LOCALE=${LOCALE:-en_US.UTF-8}

# Get keyboard layout
info "Common keymaps: us, uk, de-latin1, fr-latin1 (press Enter for 'us')"
KEYMAP=$(prompt "Enter console keymap (default: us):")
KEYMAP=${KEYMAP:-us}

# Ask about quota limits
info "Btrfs quota limits can prevent any single subvolume from consuming all disk space"
if prompt_confirm "Enable quota limits for subvolumes? (recommended)"; then
    ENABLE_QUOTAS=true
    info "Setting quota limits (these share the total disk space dynamically):"
    ROOT_QUOTA=$(prompt "Root (/) quota in GB (default: 50):")
    ROOT_QUOTA=${ROOT_QUOTA:-50}
    HOME_QUOTA=$(prompt "Home quota in GB (default: unlimited, press Enter):")
    HOME_QUOTA=${HOME_QUOTA:-0}  # 0 means unlimited
    VAR_QUOTA=$(prompt "Var quota in GB (default: 30):")
    VAR_QUOTA=${VAR_QUOTA:-30}
    TMP_QUOTA=$(prompt "Tmp quota in GB (default: 10):")
    TMP_QUOTA=${TMP_QUOTA:-10}
else
    ENABLE_QUOTAS=false
    info "Quotas disabled - all subvolumes share space without limits"
fi

# Partition the disk
info "Partitioning disk $DISK..."

# Determine partition naming scheme
if [[ "$DISK" == *"nvme"* ]]; then
	PART_PREFIX="${DISK}p"
else
	PART_PREFIX="${DISK}"
fi

EFI_PART="${PART_PREFIX}1"
LUKS_PART="${PART_PREFIX}2"

# Create GPT partition table and partitions
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 513MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary 513MiB 100%

info "Partitions created:"
lsblk "$DISK"

# Setup LUKS encryption
info "Setting up LUKS encryption on ${LUKS_PART}..."
warn "You will be prompted to enter a passphrase for disk encryption"
warn "IMPORTANT: Remember this passphrase! Without it, your data cannot be recovered."

cryptsetup luksFormat --type luks2 --pbkdf pbkdf2 "$LUKS_PART"
info "Opening encrypted partition..."
cryptsetup open "$LUKS_PART" cryptroot

# Create Btrfs filesystem
info "Creating Btrfs filesystem with compression..."
mkfs.btrfs -L MainFs /dev/mapper/cryptroot

# Mount the Btrfs filesystem to create subvolumes
info "Creating Btrfs subvolumes..."
mount /dev/mapper/cryptroot /mnt

# Create subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@snapshots

info "Btrfs subvolumes created:"
btrfs subvolume list /mnt

# Enable quotas if requested
if [ "$ENABLE_QUOTAS" = true ]; then
    info "Enabling Btrfs quotas..."
    btrfs quota enable /mnt

    info "Setting quota limits..."
    # Set quota limits (convert GB to bytes: GB * 1024^3)
    if [ "$ROOT_QUOTA" -gt 0 ]; then
        btrfs qgroup limit ${ROOT_QUOTA}G /mnt/@
        info "Root: ${ROOT_QUOTA}GB limit set"
    fi

    if [ "$HOME_QUOTA" -gt 0 ]; then
        btrfs qgroup limit ${HOME_QUOTA}G /mnt/@home
        info "Home: ${HOME_QUOTA}GB limit set"
    else
        info "Home: unlimited"
    fi

    if [ "$VAR_QUOTA" -gt 0 ]; then
        btrfs qgroup limit ${VAR_QUOTA}G /mnt/@var
        info "Var: ${VAR_QUOTA}GB limit set"
    fi

    if [ "$TMP_QUOTA" -gt 0 ]; then
        btrfs qgroup limit ${TMP_QUOTA}G /mnt/@tmp
        info "Tmp: ${TMP_QUOTA}GB limit set"
    fi

    info "Quota configuration:"
    btrfs qgroup show /mnt
fi

# Unmount to remount with proper options
umount /mnt

# Format EFI partition
info "Formatting EFI partition..."
mkfs.fat -F32 "$EFI_PART"

# Mount filesystems with optimized Btrfs options
info "Mounting filesystems with compression and optimization..."
# Mount options explanation:
# compress=zstd:1 - Fast compression (level 1) for good balance
# noatime - Don't update access times (better performance)
# space_cache=v2 - Faster free space lookups
# discard=async - TRIM support for SSDs
mount -o compress=zstd:1,noatime,space_cache=v2,discard=async,subvol=@ /dev/mapper/cryptroot /mnt
mount --mkdir -o compress=zstd:1,noatime,space_cache=v2,discard=async,subvol=@home /dev/mapper/cryptroot /mnt/home
mount --mkdir -o compress=zstd:1,noatime,space_cache=v2,discard=async,subvol=@var /dev/mapper/cryptroot /mnt/var
mount --mkdir -o compress=zstd:1,noatime,space_cache=v2,discard=async,subvol=@tmp /dev/mapper/cryptroot /mnt/tmp
mount --mkdir -o compress=zstd:1,noatime,space_cache=v2,discard=async,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
mount --mkdir "$EFI_PART" /mnt/boot

info "Mount points:"
lsblk "$DISK"

# Install base system
info "Installing base system packages..."
info "This will take several minutes depending on your internet connection..."

# Install packages
# https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages
pacstrap -K /mnt \
	base linux linux-firmware efibootmgr grub \
	intel-ucode amd-ucode sof-firmware \
	btrfs-progs iwd sudo networkmanager power-profiles-daemon \
	man-db man-pages texinfo cronie timeshift reflector \
	openssh zsh git tmux bind inetutils traceroute unzip fzf jq \
	plasma-meta sddm dolphin konsole \
	&& info "Base packages installed successfully"

# Check for NVIDIA graphics card and install drivers
info "Checking for NVIDIA graphics card..."
HAS_NVIDIA=false
if lspci | grep -i nvidia >/dev/null 2>&1; then
	info "NVIDIA graphics card detected:"
	lspci | grep -i nvidia
	info "Installing NVIDIA open kernel drivers..."
	pacstrap -K /mnt nvidia-open nvidia-prime && info "NVIDIA drivers installed successfully"
	HAS_NVIDIA=true
else
	info "No NVIDIA graphics card detected, skipping driver installation"
fi

# Generate fstab
info "Generating fstab..."
genfstab -U /mnt >>/mnt/etc/fstab

info "Verifying fstab..."
cat /mnt/etc/fstab

# Copy NetworkManager connection profiles
info "Copying NetworkManager WLAN settings..."
if [ -d /etc/NetworkManager/system-connections ] && [ "$(ls -A /etc/NetworkManager/system-connections 2>/dev/null)" ]; then
	mkdir -p /mnt/etc/NetworkManager/system-connections
	cp -r /etc/NetworkManager/system-connections/* /mnt/etc/NetworkManager/system-connections/
	chmod 600 /mnt/etc/NetworkManager/system-connections/*
	info "WLAN settings copied successfully"
else
	warn "No NetworkManager connection profiles found to copy"
fi

# Configure system in chroot
info "Configuring system..."

# Stage the chroot configuration script (lives next to this installer)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
install -m 755 "$SCRIPT_DIR/configure-chroot.sh" /mnt/root/configure.sh

# Execute configuration in chroot, passing values via environment
env \
	TIMEZONE="$TIMEZONE" \
	LOCALE="$LOCALE" \
	KEYMAP="$KEYMAP" \
	HOSTNAME="$HOSTNAME" \
	LUKS_PART="$LUKS_PART" \
	HAS_NVIDIA="$HAS_NVIDIA" \
	arch-chroot /mnt /root/configure.sh

# Cleanup
rm /mnt/root/configure.sh

# Installation complete
info "============================================"
info "Installation complete!"
info "============================================"
echo ""
warn "IMPORTANT NOTES:"
echo "1. Make sure you have recorded your LUKS encryption passphrase"
echo "2. The system will require this passphrase on every boot"
echo "3. NetworkManager has been enabled for network management"
echo "4. Btrfs filesystem with zstd compression enabled"
echo "5. SSD TRIM enabled (fstrim.timer + discard=async mount option)"
echo "6. Timeshift has been installed for Btrfs snapshots"
echo "   - Configure it after first boot with: sudo timeshift-gtk"
echo ""
info "Next steps:"
echo "1. Review the configuration if needed"
echo "2. Type 'exit' to leave the chroot environment"
echo "3. Unmount partitions: umount -R /mnt"
echo "4. Reboot: reboot"
echo "5. Remove installation media and boot into new system"
echo ""
warn "After first boot, remember to:"
echo "- Configure timeshift for automatic Btrfs snapshots"
echo "- Btrfs provides native snapshots - instant and space-efficient!"
echo "- All subvolumes share space dynamically (no fixed sizes)"
echo "- Configure additional users"
echo ""

info "Press Enter to finish..."
read -r
