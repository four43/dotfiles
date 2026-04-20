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

cat <<'EOF'

-------------------------------------------------------------------------
Now pair the controller:

  1. Press the Xbox button to power on.
  2. Hold the small PAIR button (top edge near USB-C port) for ~3s until
     the Xbox logo flashes RAPIDLY.
  3. In another terminal, run:

       bluetoothctl
       [bluetooth]# scan on
       # wait a few seconds for "Xbox Wireless Controller" to appear
       [bluetooth]# pair    <MAC>
       [bluetooth]# trust   <MAC>
       [bluetooth]# connect <MAC>
       [bluetooth]# scan off
       [bluetooth]# quit

Verify:
  lsmod | grep xpadneo          # hid_xpadneo should be loaded
  ls /dev/input/js*             # a new jsN device should appear
  jstest /dev/input/jsN         # move sticks to see events

If it still blinks forever, ERTM didn't take effect — re-check with:
  cat /sys/module/bluetooth/parameters/disable_ertm   # must print: Y
-------------------------------------------------------------------------
EOF
