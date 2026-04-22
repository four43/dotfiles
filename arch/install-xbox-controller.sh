#!/bin/bash

# https://atar-axis.github.io/xpadneo/
# https://wiki.archlinux.org/title/Xbox_Wireless_Controller
#
# Xbox Series X|S controllers reach Linux three ways:
#   - USB cable              -> kernel hid-generic (no FFB), or xone if
#                               unblacklisted (we blacklist it for the G923
#                               wheel — see install-g923-wheel.sh).
#   - Xbox Wireless Adapter  -> xone-dongle.
#   - Bluetooth              -> xpadneo-dkms. This script's focus.
#
# Classic BT pairing failure: Xbox button blinks forever. Cause is BlueZ
# ERTM (Enhanced Re-Transmission Mode); Xbox controllers don't support it,
# so pairing half-succeeds and silently drops. Fix is to disable ERTM
# kernel-wide.

set -euo pipefail

echo "=== Bluetooth adapters ==="
bluetoothctl list || true
echo

echo "=== Paired devices ==="
bluetoothctl devices || true
echo

echo "=== ERTM status (want: Y) ==="
cat /sys/module/bluetooth/parameters/disable_ertm 2>/dev/null \
    || echo "(bluetooth module not loaded)"
echo

echo "=== xpadneo install status ==="
pacman -Qi xpadneo-dkms >/dev/null 2>&1 \
    && echo "xpadneo-dkms installed" \
    || echo "(not installed)"
echo

echo "=== Install xpadneo-dkms ==="
sudo pacman -S --needed linux-headers
yay -S --needed xpadneo-dkms

echo
echo "=== Disable ERTM persistently ==="
sudo tee /etc/modprobe.d/xpadneo.conf >/dev/null <<'EOF'
# Xbox Wireless controllers don't support Bluetooth ERTM. Without this
# disabled, pairing half-succeeds and silently drops — Xbox button blinks
# forever. https://atar-axis.github.io/xpadneo/
options bluetooth disable_ertm=1
EOF

echo
echo "=== Apply ERTM change live ==="
echo 1 | sudo tee /sys/module/bluetooth/parameters/disable_ertm >/dev/null
echo -n "disable_ertm is now: "
cat /sys/module/bluetooth/parameters/disable_ertm

echo
echo "=== Restart bluetooth service ==="
sudo systemctl restart bluetooth

echo
read -rp "Pair a controller now? [Y/n] " reply
if [[ ${reply,,} =~ ^(n|no)$ ]]; then
    echo "Skipping pairing. Re-run this script or use bluetoothctl to pair later."
    exit 0
fi

echo
echo "=== Power on Bluetooth ==="
sudo rfkill unblock bluetooth || true
bluetoothctl power on >/dev/null
bluetoothctl agent on >/dev/null
bluetoothctl default-agent >/dev/null 2>&1 || true

cat <<'EOF'

-------------------------------------------------------------------------
Put the controller in pairing mode:
  1. Press the Xbox button to power on.
  2. Hold the PAIR button (top edge near USB-C) for ~3s until the Xbox
     logo flashes RAPIDLY (not the slow pulse).
-------------------------------------------------------------------------
EOF
read -rp "Press Enter when the Xbox logo is flashing rapidly... "

echo
echo "=== Scanning for Xbox Wireless Controller (up to 30s) ==="
bluetoothctl --timeout 30 scan on >/dev/null &
scan_pid=$!
trap 'kill "$scan_pid" 2>/dev/null || true; wait "$scan_pid" 2>/dev/null || true' EXIT

mac=""
for _ in $(seq 1 30); do
    mac=$(bluetoothctl devices | awk '/Xbox Wireless Controller/ {print $2; exit}')
    [[ -n $mac ]] && break
    sleep 1
done

kill "$scan_pid" 2>/dev/null || true
wait "$scan_pid" 2>/dev/null || true
trap - EXIT

if [[ -z $mac ]]; then
    echo "No Xbox Wireless Controller found."
    echo "Confirm rapid flashing, then re-run. ERTM check:"
    cat /sys/module/bluetooth/parameters/disable_ertm
    exit 1
fi

echo "Found: $mac"

echo
echo "=== Pair / trust / connect ==="
bluetoothctl pair    "$mac" || echo "(pair failed or already paired — continuing)"
bluetoothctl trust   "$mac"
bluetoothctl connect "$mac"

echo
echo "=== Wait for driver + input device (up to 20s) ==="
js=""
shopt -s nullglob
for _ in $(seq 1 20); do
    js_devs=(/dev/input/js*)
    js=${js_devs[0]:-}
    if [[ -n $js ]] && lsmod | grep -q '^hid_xpadneo'; then
        break
    fi
    sleep 1
done
shopt -u nullglob

if lsmod | grep -q '^hid_xpadneo'; then
    echo "hid_xpadneo: loaded"
else
    echo "hid_xpadneo: NOT loaded — try pressing a button on the controller"
fi

if [[ -n $js ]]; then
    echo "Input device: $js"
else
    echo "No /dev/input/jsN appeared. Press a button, then check: ls /dev/input/js*"
fi

cat <<EOF

Test input:  jstest ${js:-/dev/input/jsN}
Controller:  $mac
EOF
