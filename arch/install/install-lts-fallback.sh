#!/bin/bash
# One-time setup: add linux-lts as a fallback kernel with GPU support.
#
# Why:
#   Single-kernel systems have no rescue path when a `linux` upgrade removes
#   the old `/usr/lib/modules/<version>` directory or overwrites vmlinuz in
#   the ESP. A timeshift/Btrfs rollback cannot restore /boot (it's on the
#   FAT32 ESP, outside the snapshot), so a snapshot alone does not save you.
#
#   linux-lts is a second, always-installed kernel that shares neither its
#   vmlinuz filename nor its /usr/lib/modules/<version> directory with linux.
#   Result: an upgrade of `linux` cannot make LTS unbootable.
#
# What this does:
#   1. Switch nvidia-open -> nvidia-open-dkms.
#      The prebuilt nvidia-open is compiled against `linux` only. DKMS
#      rebuilds the module for every installed kernel with headers, so both
#      kernels get real GPU acceleration. Cost: ~1 minute per kernel upgrade.
#   2. Install linux-lts + linux-lts-headers.
#      pacman's mkinitcpio hook rebuilds initramfs and the linux-lts
#      preset ships a fallback initramfs too.
#   3. Regenerate GRUB config so both kernels appear in the boot menu.
#
# When to run: once, after a normal boot into the primary system. Not from
# the live ISO.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "$@" >&2; }
info() { log "${GREEN}[INFO]${NC} $*"; }
warn() { log "${YELLOW}[WARN]${NC} $*"; }
err()  { log "${RED}[ERROR]${NC} $*"; exit 1; }
step() { log; log "${BLUE}==>${NC} $*"; }

confirm() {
	local message="$1" response
	while true; do
		echo -en "${YELLOW}[CONFIRM]${NC} $message (y/n): " >&2
		read -r response
		case "$response" in
		[yY]|[yY][eE][sS]) return 0 ;;
		[nN]|[nN][oO])     return 1 ;;
		*) echo "Please answer yes or no." >&2 ;;
		esac
	done
}

# --- Preflight --------------------------------------------------------------
[ "$EUID" -ne 0 ] || err "Run as your normal user (script uses sudo); do not run as root."
command -v pacman >/dev/null    || err "pacman not found — not an Arch system?"
command -v grub-mkconfig >/dev/null || err "grub-mkconfig not found — is this a GRUB-booted install?"
[ -f /boot/grub/grub.cfg ]      || err "/boot/grub/grub.cfg missing — GRUB not installed to /boot?"

log "=== linux-lts fallback kernel setup ==="
log
log "Running kernel:      $(uname -r)"
log "Installed kernels:   $(pacman -Qq | grep -E '^linux(-lts|-zen|-hardened)?$' | tr '\n' ' ')"
log "Installed NVIDIA:    $(pacman -Qq | grep -E '^(nvidia|nvidia-open|nvidia-lts|nvidia-open-dkms|nvidia-dkms)$' | tr '\n' ' ')"
log

if pacman -Qq linux-lts >/dev/null 2>&1; then
	warn "linux-lts is already installed. This script is a no-op."
	warn "If you want to add DKMS driver, run: sudo pacman -S nvidia-open-dkms"
	exit 0
fi

confirm "This will install linux-lts and swap nvidia-open -> nvidia-open-dkms. Proceed?" \
	|| { info "Aborted."; exit 0; }

# --- Driver swap ------------------------------------------------------------
# Do the driver swap FIRST so that when linux-lts is installed, the DKMS
# hook builds the module for both kernels in one pass.
step "[1/3] Swap nvidia-open -> nvidia-open-dkms"
if pacman -Qq nvidia-open >/dev/null 2>&1; then
	# `pacman -S nvidia-open-dkms` resolves the conflict interactively and
	# also pulls dkms itself. We stay interactive: --noconfirm here could
	# silently remove the running GPU driver on a bad prompt.
	sudo pacman -S nvidia-open-dkms
elif pacman -Qq nvidia-open-dkms >/dev/null 2>&1; then
	info "nvidia-open-dkms already installed. Skipping swap."
else
	warn "No nvidia-open* package detected. Installing nvidia-open-dkms fresh."
	sudo pacman -S nvidia-open-dkms
fi

# --- LTS kernel -------------------------------------------------------------
step "[2/3] Install linux-lts + headers"
# Headers are required for DKMS to build the nvidia module against LTS.
# Installing them triggers the DKMS hook automatically.
sudo pacman -S linux-lts linux-lts-headers

# Confirm the modules built against LTS. If this file is missing after the
# install, DKMS silently failed and LTS will boot without GPU accel.
lts_ver=$(pacman -Q linux-lts | awk '{print $2}' | sed 's/\.arch/-arch/')
lts_modules_dir=$(ls -d /usr/lib/modules/*"-lts" 2>/dev/null | head -1 || true)
if [ -z "$lts_modules_dir" ]; then
	warn "Could not locate /usr/lib/modules/*-lts. DKMS may not have built."
else
	if find "$lts_modules_dir" -name 'nvidia*.ko*' -print -quit | grep -q .; then
		info "nvidia module present under $lts_modules_dir"
	else
		warn "No nvidia*.ko under $lts_modules_dir — DKMS build failed."
		warn "Check: sudo dkms status"
	fi
fi

# --- GRUB -------------------------------------------------------------------
step "[3/3] Regenerate GRUB config"
# mkinitcpio hooks already built LTS initramfs. This picks it up as a
# second top-level GRUB entry (plus a fallback under "Advanced options").
sudo grub-mkconfig -o /boot/grub/grub.cfg

log
log "=== Done ==="
log
log "Next steps:"
log "  1. Reboot and pick 'Advanced options for Arch Linux' at the GRUB menu."
log "  2. Verify a linux-lts entry exists and boots to a graphical session."
log "  3. From within LTS, confirm 'nvidia-smi' works (DKMS built correctly)."
log "  4. Reboot back into the default kernel."
log
log "You now have a rescue kernel. If a future 'linux' upgrade breaks boot,"
log "select the linux-lts entry from GRUB and use it to repair the system."
