#!/bin/bash
# Bring up the Vagrant test VM and serve the install scripts so the
# live ISO inside the VM can curl them down to /tmp/.
#
# Host dependencies (Arch):
sudo pacman -S --needed libvirt qemu-base virt-viewer virt-install dnsmasq iptables-nft xdotool python libxslt libxml2 pkgconf base-devel
sudo systemctl enable --now libvirtd.service
#   sudo usermod -aG libvirt "$USER"   # log out/in after this
#   CONFIGURE_ARGS='with-ldflags=-L/opt/vagrant/embedded/lib with-libvirt-include=/usr/include/libvirt with-libvirt-lib=/usr/lib' \
#     PKG_CONFIG_PATH=/opt/vagrant/embedded/lib/pkgconfig \
#     vagrant plugin install vagrant-libvirt
#
# See README.md for full setup notes.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# vagrant-libvirt names the domain "<dirname>_<machine>"; our Vagrantfile
# uses the default machine name, so this is what virt-viewer / virsh see.
VM_NAME="$(basename "$SCRIPT_DIR")_default"

info "Bringing up VM '$VM_NAME' (no-op if already running)..."
vagrant up --provider=libvirt

# Open a console so the user can see the live ISO. serve-script.sh
# will then xdotool-type the curl command into this window.
if command -v virt-viewer >/dev/null 2>&1; then
	if ! pgrep -f "virt-viewer.*$VM_NAME" >/dev/null 2>&1; then
		info "Opening virt-viewer window for $VM_NAME..."
		virt-viewer --connect qemu:///system --domain-name "$VM_NAME" >/dev/null 2>&1 &
		sleep 2
	else
		info "virt-viewer already open for $VM_NAME."
	fi
else
	warn "virt-viewer not installed — open the VM console manually (virt-manager)."
fi

info "Starting HTTP server (Ctrl+C to stop, then 'vagrant destroy' to clean up)..."
exec "$SCRIPT_DIR/serve-script.sh"
