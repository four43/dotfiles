#!/bin/bash
# Bring up the Arch live ISO test VM, then serve install-arch.sh over HTTP.
# Run ./host-install.sh once before the first invocation.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

export VM_NAME="arch-install-test"
ISO_URL="https://fastly.mirror.pkgbuild.com/iso/2026.05.01/archlinux-2026.05.01-x86_64.iso"
ISO_PATH="$SCRIPT_DIR/archlinux-2026.05.01-x86_64.iso"
VIRSH="virsh -c qemu:///system"

# --- Sanity check ---------------------------------------------------------
for cmd in virt-install virsh ydotool; do
	if ! command -v "$cmd" >/dev/null; then
		warn "$cmd not found — run ./host-install.sh first."
		exit 1
	fi
done

# --- ydotoold (per shell session) -----------------------------------------
# Daemon writes to /dev/uinput (root-only); socket is chowned to the user.
YDOTOOL_SOCK="/tmp/ydotoold-$UID.sock"
if ! pgrep -f "ydotoold.*$YDOTOOL_SOCK" >/dev/null 2>&1; then
	info "Starting ydotoold (one sudo prompt per shell session)..."
	sudo -b ydotoold --socket-path="$YDOTOOL_SOCK" \
		--socket-own="$UID:$UID" --socket-perm=0600 >/dev/null 2>&1
	for _ in 1 2 3 4 5; do
		[[ -S $YDOTOOL_SOCK ]] && break
		sleep 0.2
	done
fi
export YDOTOOL_SOCKET="$YDOTOOL_SOCK"

# --- Default libvirt network ----------------------------------------------
if ! $VIRSH net-list --name 2>/dev/null | grep -qFx default; then
	info "Starting libvirt default network..."
	$VIRSH net-start default
fi

# --- Download ISO ---------------------------------------------------------
if [[ ! -f $ISO_PATH ]]; then
	info "Downloading Arch ISO to $ISO_PATH..."
	curl -L --fail --output "$ISO_PATH" "$ISO_URL"
fi

# --- VM lifecycle (idempotent) --------------------------------------------
if ! $VIRSH dominfo "$VM_NAME" >/dev/null 2>&1; then
	info "Creating VM '$VM_NAME' with virt-install..."
	virt-install \
		--connect qemu:///system \
		--name "$VM_NAME" \
		--memory 4096 \
		--vcpus 2 \
		--osinfo archlinux \
		--machine q35 \
		--boot uefi,hd,cdrom \
		--disk size=40,format=qcow2,bus=virtio \
		--cdrom "$ISO_PATH" \
		--network network=default,model=virtio \
		--graphics spice \
		--video qxl \
		--channel spicevmc \
		--noautoconsole \
		--wait 0
elif ! $VIRSH list --name | grep -qx "$VM_NAME"; then
	info "VM '$VM_NAME' is defined but not running — starting..."
	$VIRSH start "$VM_NAME"
else
	info "VM '$VM_NAME' is already running."
fi

# --- Console window -------------------------------------------------------
if ! pgrep -f "virt-viewer.*$VM_NAME" >/dev/null 2>&1; then
	info "Opening virt-viewer window..."
	virt-viewer --connect qemu:///system --domain-name "$VM_NAME" >/dev/null 2>&1 &
	sleep 2
else
	info "virt-viewer already open for $VM_NAME."
fi

info "Starting HTTP server (Ctrl+C to stop, then './cleanup.sh' to tear down)..."
exec "$SCRIPT_DIR/serve-script.sh"
