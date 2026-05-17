#!/bin/bash
# One-time host setup for the Arch install testing VM.
# Idempotent — safe to re-run.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# --- Packages -------------------------------------------------------------
# qemu-desktop is a meta-package that pulls qemu-base + display/chardev/audio
# modules (qxl, spice, etc.) needed for a desktop-grade VM console.
info "Installing host packages..."
sudo pacman -S --needed libvirt qemu-desktop virt-viewer virt-install \
	dnsmasq iptables-nft ydotool libosinfo

# --- libvirtd -------------------------------------------------------------
sudo systemctl enable --now libvirtd.service

# --- nftables firewall backend --------------------------------------------
# When Docker is installed it manages iptables-nft, which prevents libvirt's
# default iptables backend from successfully installing NAT rules for virbr0
# (VMs end up isolated). The native nftables backend writes to its own
# libvirt_network table, sidestepping the conflict entirely.
if ! grep -qE '^[[:space:]]*firewall_backend' /etc/libvirt/network.conf 2>/dev/null; then
	info "Configuring libvirt to use the native nftables firewall backend..."
	echo 'firewall_backend = "nftables"' | sudo tee -a /etc/libvirt/network.conf >/dev/null
	sudo systemctl restart libvirtd
	# Bounce the default network so it re-installs rules under the new backend.
	virsh -c qemu:///system net-destroy default >/dev/null 2>&1 || true
	virsh -c qemu:///system net-start default >/dev/null 2>&1 || true
fi
virsh -c qemu:///system net-autostart default >/dev/null 2>&1 || true

# --- Docker / libvirt forward-chain coexistence ---------------------------
# Docker sets the host FORWARD policy to DROP. That blocks outbound traffic
# from libvirt VMs even when libvirt's own NAT rules are correctly in place
# (the VM gets DHCP, can reach 192.168.122.1, but can't forward to the wider
# internet). Docker provides the DOCKER-USER chain as the canonical escape
# hatch: rules we add there run before Docker's default-deny, and Docker
# preserves them across daemon restarts.
#
# We install a libvirt network hook that adds the ACCEPT rules whenever the
# default network starts (and removes them on stop), so the integration is
# tied to libvirt's lifecycle rather than a one-shot setup that drifts.
HOOK_PATH=/etc/libvirt/hooks/network
info "Installing/refreshing libvirt network hook at $HOOK_PATH..."
sudo mkdir -p "$(dirname "$HOOK_PATH")"
sudo tee "$HOOK_PATH" >/dev/null <<-'HOOK'
		#!/bin/bash
		# libvirt network hook: when the default network starts, punch a
		# hole through Docker's FORWARD chain so VMs can reach the internet.
		set -u
		NETWORK="$1"
		ACTION="$2"

		[[ $NETWORK != default ]] && exit 0

		# If Docker isn't running, DOCKER-USER doesn't exist — no-op.
		iptables -nL DOCKER-USER >/dev/null 2>&1 || exit 0

		case "$ACTION" in
		    started)
		        for dir in -i -o; do
		            iptables -C DOCKER-USER $dir virbr0 -j ACCEPT 2>/dev/null \
		                || iptables -I DOCKER-USER $dir virbr0 -j ACCEPT
		        done
		        ;;
		    stopped)
		        for dir in -i -o; do
		            iptables -D DOCKER-USER $dir virbr0 -j ACCEPT 2>/dev/null || true
		        done
		        ;;
		esac
		exit 0
	HOOK
sudo chmod 0755 "$HOOK_PATH"

# Apply the rules right now in case the default network is already running
# (the hook only fires on net-start, not on this script's first run).
if sudo iptables -nL DOCKER-USER >/dev/null 2>&1; then
	for dir in -i -o; do
		sudo iptables -C DOCKER-USER $dir virbr0 -j ACCEPT 2>/dev/null \
			|| sudo iptables -I DOCKER-USER $dir virbr0 -j ACCEPT
	done
fi

# --- libvirt group --------------------------------------------------------
# Arch ships /usr/share/polkit-1/rules.d/50-libvirt.rules which bypasses
# polkit auth for libvirt group members — without group membership every
# vagrant-libvirt / virsh call triggers a KDE auth popup.
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx libvirt; then
	info "Adding $USER to the libvirt group..."
	sudo usermod -aG libvirt "$USER"
	NEED_RELOGIN=1
fi

# --- ACL: libvirt-qemu traverse on $HOME ---------------------------------
# libvirt-qemu (the user qemu runs as) needs to traverse $HOME to read the
# ISO. Surgical ACL grant — $HOME's mode bits stay 700 to everyone else.
if ! getfacl -p "$HOME" 2>/dev/null | grep -q '^user:libvirt-qemu:..x'; then
	info "Granting libvirt-qemu traverse access to $HOME via ACL..."
	setfacl -m u:libvirt-qemu:x "$HOME"
fi

echo
info "Host setup complete."
if [[ ${NEED_RELOGIN:-0} -eq 1 ]]; then
	warn "Log out of your desktop session and back in for libvirt group"
	warn "membership to apply. Until then expect polkit auth popups."
fi
echo "Next: ./test.sh"
