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

# Pull both scripts into /tmp/ so install-arch.sh can locate configure-chroot.sh
# as a sibling via $BASH_SOURCE.
CURL_CMD="curl -fsSL http://${LIBVIRT_IP}:${PORT}/install-arch.sh -o /tmp/install-arch.sh && curl -fsSL http://${LIBVIRT_IP}:${PORT}/configure-chroot.sh -o /tmp/configure-chroot.sh && chmod +x /tmp/install-arch.sh /tmp/configure-chroot.sh"

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

set -x
# Try to auto-type into VM console window using xdotool
if command -v xdotool &> /dev/null; then
    echo "Attempting to auto-type command into VM window in 3 seconds..."
    echo "(Make sure virt-viewer window is focused)"
    sleep 3

    # libvirt names the VM window after the directory the Vagrantfile lives in.
    VM_WINDOW_NAME="$(basename "$SCRIPT_DIR")_default"
	set +e
    VM_WINDOW=$(xdotool search --name "$VM_WINDOW_NAME" 2>/dev/null | head -1)
	set -e
    if [ -n "$VM_WINDOW" ]; then
        xdotool windowactivate --sync "$VM_WINDOW"
        sleep 0.5
        xdotool type --delay 50 "$CURL_CMD"
        echo "Command typed into VM window!"
    else
        echo "VM window not found. Please manually type the command above."
        echo "Debug: Available windows:"
        xdotool search --name "" | while read wid; do
            echo "  Window $wid: $(xdotool getwindowname $wid)"
        done
    fi
else
    echo "xdotool not installed. Please manually type the command above."
    echo "Install with: sudo pacman -S xdotool"
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
