#!/bin/bash
# Write an Arch Linux installer USB, with an optional ext4 sidecar partition
# containing the install scripts from this directory and (optionally) SSH keys.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

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
		echo -en "${YELLOW}[CONFIRM]${NC} $message (y/n): " >&2
		read -r response
		case "$response" in
		[yY] | [yY][eE][sS]) return 0 ;;
		[nN] | [nN][oO]) return 1 ;;
		*) echo "Please answer yes or no." >&2 ;;
		esac
	done
}

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ARCH_MIRROR="https://archlinux.org/iso/latest"
MOUNT_POINT=""

cleanup() {
	if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
		if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
			umount "$MOUNT_POINT" 2>/dev/null || true
		fi
		rmdir "$MOUNT_POINT" 2>/dev/null || true
	fi
}
trap cleanup EXIT

# ---------- Sanity checks ----------

if [[ "$EUID" -ne 0 ]]; then
	error "This script must be run as root (use sudo)."
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
[[ -d "$REAL_HOME" ]] || error "Could not resolve home directory for user $REAL_USER"
ISO_CACHE_DIR="${REAL_HOME}/Downloads"

for tool in lsblk sgdisk mkfs.ext4 dd curl partprobe findmnt; do
	command -v "$tool" >/dev/null 2>&1 || error "Required tool not found: $tool"
done

# ---------- Locate ISO ----------

find_local_iso() {
	[[ -d "$ISO_CACHE_DIR" ]] || return 0
	find "$ISO_CACHE_DIR" -maxdepth 1 -type f -name 'archlinux-*-x86_64.iso' -printf '%T@ %p\n' 2>/dev/null |
		sort -nr | head -n1 | cut -d' ' -f2-
}

download_iso() {
	mkdir -p "$ISO_CACHE_DIR"
	chown "$REAL_USER:" "$ISO_CACHE_DIR" 2>/dev/null || true

	info "Looking up latest Arch ISO filename..." >&2
	local filename
	filename=$(curl -fsSL "$ARCH_MIRROR/" | grep -oE 'archlinux-[0-9.]+-x86_64\.iso' | head -n1)
	[[ -n "$filename" ]] || error "Could not determine latest Arch ISO filename from $ARCH_MIRROR"

	local target="$ISO_CACHE_DIR/$filename"
	info "Downloading $filename ..." >&2
	sudo -u "$REAL_USER" curl -fL --progress-bar -o "$target" "$ARCH_MIRROR/$filename" >&2

	info "Fetching signature ..." >&2
	if sudo -u "$REAL_USER" curl -fsSL -o "$target.sig" "$ARCH_MIRROR/$filename.sig"; then
		if command -v gpg >/dev/null 2>&1; then
			info "Verifying signature ..." >&2
			if sudo -u "$REAL_USER" gpg --auto-key-locate clear,wkd,dane,keyserver \
				--verify "$target.sig" "$target" >&2 2>&1; then
				info "Signature verified." >&2
			else
				warn "Signature verification failed or signer untrusted; continuing anyway." >&2
			fi
		else
			warn "gpg not installed; skipping signature verification." >&2
		fi
	else
		warn "Could not fetch signature; skipping verification." >&2
	fi

	echo "$target"
}

info "Looking for an Arch ISO in $ISO_CACHE_DIR ..."
ISO_PATH=$(find_local_iso || true)
if [[ -n "$ISO_PATH" ]]; then
	info "Found: $ISO_PATH"
	if ! prompt_confirm "Use this ISO?"; then
		ISO_PATH=$(download_iso)
	fi
else
	info "No local ISO found."
	ISO_PATH=$(download_iso)
fi
[[ -f "$ISO_PATH" ]] || error "ISO not found: $ISO_PATH"

# ---------- Device selection ----------

list_usb_disks() {
	lsblk -dn -o NAME,TRAN,RM,TYPE |
		awk '$2=="usb" && $3=="1" && $4=="disk" {print $1}'
}

describe_device() {
	local name="$1"
	local size model vendor
	size=$(lsblk -dn -o SIZE "/dev/$name" | tr -d ' ')
	model=$(lsblk -dn -o MODEL "/dev/$name" | sed 's/[[:space:]]\+$//')
	vendor=$(lsblk -dn -o VENDOR "/dev/$name" | sed 's/[[:space:]]\+$//')
	printf "%-8s %-10s %-20s %s" "$name" "$size" "${vendor:-?}" "${model:-?}"
}

mapfile -t USB_DISKS < <(list_usb_disks)
if [[ ${#USB_DISKS[@]} -eq 0 ]]; then
	error "No removable USB disks found. Plug one in and try again."
fi

info "Available USB disks:"
echo
printf "  %-4s %-8s %-10s %-20s %s\n" "#" "NAME" "SIZE" "VENDOR" "MODEL"
echo "  ----------------------------------------------------------------------"
for i in "${!USB_DISKS[@]}"; do
	printf "  [%d]  %s\n" "$((i + 1))" "$(describe_device "${USB_DISKS[$i]}")"
done
echo

SEL=""
while true; do
	SEL=$(prompt "Select device by number (1-${#USB_DISKS[@]}):")
	if [[ "$SEL" =~ ^[0-9]+$ ]] && ((SEL >= 1 && SEL <= ${#USB_DISKS[@]})); then
		break
	fi
	warn "Invalid selection."
done

DEV_NAME="${USB_DISKS[$((SEL - 1))]}"
DEV_PATH="/dev/$DEV_NAME"
[[ -b "$DEV_PATH" ]] || error "Device $DEV_PATH does not exist."

# Refuse to write to the disk hosting /
ROOT_DEV=$(findmnt -n -o SOURCE / | sed -E 's/p?[0-9]+$//')
if [[ "$ROOT_DEV" == "$DEV_PATH" ]]; then
	error "$DEV_PATH appears to host the running root filesystem. Refusing."
fi

# ---------- Double-check ----------

echo
warn "About to ERASE this device — all data will be lost:"
echo
lsblk "$DEV_PATH"
echo
warn "Type the device name (without /dev/) to confirm: ${DEV_NAME}"
TYPED=$(prompt "Type to confirm:")
if [[ "$TYPED" != "$DEV_NAME" ]]; then
	error "Confirmation did not match. Aborting."
fi

# ---------- Unmount any existing partitions ----------

info "Unmounting any mounted partitions on $DEV_PATH ..."
while read -r part; do
	[[ -z "$part" || "$part" == "$DEV_NAME" ]] && continue
	umount "/dev/$part" 2>/dev/null || true
done < <(lsblk -ln -o NAME "$DEV_PATH")

# ---------- Write the ISO ----------

info "Writing ISO to $DEV_PATH (this will take several minutes)..."
dd if="$ISO_PATH" of="$DEV_PATH" bs=4M status=progress conv=fsync
sync
info "ISO written."

partprobe "$DEV_PATH" 2>/dev/null || true
sleep 2

# Some desktops auto-mount; unmount again just in case.
while read -r part; do
	[[ -z "$part" || "$part" == "$DEV_NAME" ]] && continue
	umount "/dev/$part" 2>/dev/null || true
done < <(lsblk -ln -o NAME "$DEV_PATH")

# ---------- Sidecar partition ----------

if prompt_confirm "Add a sidecar partition with install scripts (and optionally SSH keys)?"; then
	info "Moving GPT backup header to end of disk to reclaim trailing free space..."
	sgdisk -e "$DEV_PATH" >/dev/null

	BEFORE_PARTS=$(lsblk -ln -o NAME "$DEV_PATH" | tail -n +2 | sort)

	info "Creating sidecar partition (ext4, label ARCHSCRIPTS)..."
	sgdisk -n 0:0:0 -t 0:8300 -c 0:ARCHSCRIPTS "$DEV_PATH" >/dev/null
	partprobe "$DEV_PATH" 2>/dev/null || true
	sleep 2

	AFTER_PARTS=$(lsblk -ln -o NAME "$DEV_PATH" | tail -n +2 | sort)
	SIDECAR_PART=$(comm -13 <(echo "$BEFORE_PARTS") <(echo "$AFTER_PARTS") | head -n1)
	if [[ -z "$SIDECAR_PART" ]]; then
		error "Could not identify newly-created sidecar partition."
	fi
	SIDECAR_PATH="/dev/$SIDECAR_PART"
	[[ -b "$SIDECAR_PATH" ]] || error "Sidecar partition $SIDECAR_PATH not found."

	mkfs.ext4 -F -L ARCHSCRIPTS "$SIDECAR_PATH" >/dev/null

	MOUNT_POINT=$(mktemp -d -t archusb.XXXXXX)
	mount "$SIDECAR_PATH" "$MOUNT_POINT"

	info "Copying install scripts ..."
	mkdir -p "$MOUNT_POINT/install"
	cp "$SCRIPT_DIR/install-arch.sh" "$MOUNT_POINT/install/"
	cp "$SCRIPT_DIR/configure-chroot.sh" "$MOUNT_POINT/install/"
	# Personal user setup (smiller + sshd port 289). Optional: skip silently
	# if absent — install-arch.sh also skips the step when these aren't there.
	if [[ -f "$SCRIPT_DIR/configure-user.sh" ]]; then
		cp "$SCRIPT_DIR/configure-user.sh" "$MOUNT_POINT/install/"
	fi
	if [[ -d "$SCRIPT_DIR/files" ]]; then
		mkdir -p "$MOUNT_POINT/install/files"
		cp -a "$SCRIPT_DIR/files/." "$MOUNT_POINT/install/files/"
	fi
	chmod +x "$MOUNT_POINT/install/"*.sh

	if prompt_confirm "Add SSH keys to the sidecar?"; then
		DEFAULT_KEYS=(
			"$REAL_HOME/.ssh/id_ed25519"
			"$REAL_HOME/.ssh/id_ed25519.pub"
			"$REAL_HOME/.ssh/config"
		)
		info "Defaults: ${DEFAULT_KEYS[*]}"
		FILES_INPUT=$(prompt "Files to copy (space-separated, blank = defaults):")

		if [[ -z "$FILES_INPUT" ]]; then
			files=("${DEFAULT_KEYS[@]}")
		else
			# shellcheck disable=SC2206
			files=($FILES_INPUT)
		fi

		mkdir -p "$MOUNT_POINT/ssh"
		chmod 700 "$MOUNT_POINT/ssh"
		for f in "${files[@]}"; do
			f="${f/#\~/$REAL_HOME}"
			if [[ ! -f "$f" ]]; then
				warn "Skipping (not a file): $f"
				continue
			fi
			base=$(basename "$f")
			cp "$f" "$MOUNT_POINT/ssh/$base"
			if [[ "$base" == *.pub ]]; then
				chmod 644 "$MOUNT_POINT/ssh/$base"
			else
				chmod 600 "$MOUNT_POINT/ssh/$base"
			fi
			info "Copied $base"
		done
	fi

	sync
	info "Sidecar contents:"
	ls -la "$MOUNT_POINT"
	[[ -d "$MOUNT_POINT/install" ]] && ls -la "$MOUNT_POINT/install"
	[[ -d "$MOUNT_POINT/ssh" ]] && ls -la "$MOUNT_POINT/ssh"

	umount "$MOUNT_POINT"
	rmdir "$MOUNT_POINT"
	MOUNT_POINT=""
fi

sync
info "============================================"
info "Done. You can safely remove $DEV_PATH."
info "============================================"
