#!/bin/bash
# Script to serve install-arch.sh (and its sibling configure-chroot.sh) via HTTP to the VM

set -euo pipefail

# Serve from the install/ directory (parent of this script's directory)
# so install-arch.sh AND configure-chroot.sh are both reachable.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
INSTALL_DIR=$(dirname "$SCRIPT_DIR")
cd "$INSTALL_DIR"

# Find the libvirt network interface IP (typically virbr0)
LIBVIRT_IP=$(ip addr show | grep 'virbr' | sed -n '2p' | awk '{print $2}' | cut -d/ -f1)

# If still not found, use a common default
if [ -z "$LIBVIRT_IP" ]; then
	echo "Could not determine libvirt network IP" >&1
	exit 1
fi

PORT=8000

# Bundle the installer + its siblings into a tarball so the VM only needs one
# curl. install-arch.sh resolves siblings via $BASH_SOURCE, so the layout
# under /tmp/ must mirror the install/ directory.
BUNDLE=install-bundle.tar
tar -cf "$BUNDLE" \
	install-arch.sh \
	configure-chroot.sh \
	configure-user.sh \
	files/smiller.pub \
	files/system-update.sh

CURL_CMD="curl -fsSL http://${LIBVIRT_IP}:${PORT}/${BUNDLE} | tar xC /tmp && chmod +x /tmp/install-arch.sh /tmp/configure-chroot.sh /tmp/configure-user.sh"

echo "=========================================="
echo "HTTP Server for Arch Install Script"
echo "=========================================="
echo ""
echo "Host IP: $LIBVIRT_IP"
echo "Port: $PORT"
echo ""
echo "Command to run in VM:"
echo "  $CURL_CMD"
echo ""

if command -v ydotool &> /dev/null && [ -S "${YDOTOOL_SOCKET:-}" ]; then
    echo
    echo "================================================="
    echo "Wait for the VM to finish booting and show the"
    echo "root@archiso prompt, then come back here and"
    echo "press ENTER to begin auto-typing."
    echo "================================================="
    read -r -p ""
    echo "Click on the virt-viewer window — typing in 5 seconds..."
    sleep 5
    ydotool type --key-delay 30 -- "$CURL_CMD"
    echo "Command typed (no Enter). Wait for the HTTP server below to"
    echo "print 'Serving HTTP...', then press Enter in the VM yourself."
else
    echo "ydotool/ydotoold not available. Type the curl command manually (above)."
fi

echo ""
echo "Then execute the script in VM:"
echo "  /tmp/install-arch.sh"
echo ""
echo "=========================================="
echo "Starting HTTP server..."
echo "Press Ctrl+C to stop the server"
echo "=========================================="
echo ""

# Start Python HTTP server
python -m http.server $PORT
