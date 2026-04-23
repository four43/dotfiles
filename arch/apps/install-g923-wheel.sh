#!/bin/bash

# https://wiki.archlinux.org/title/Logitech_Racing_Wheel
#
# G923 comes in two variants:
#   - 046d:c266/c267  G923 for PlayStation/PC  -> HID++ directly. Handled by
#                     hid-logitech-hidpp; new-lg4ff-dkms-git gives stronger FFB.
#   - 046d:c26d       G923 for Xbox One/PC     -> HID++ *after* a usb_modeswitch
#                     flip. The wheel enumerates in Xbox compat mode on every
#                     plug-in and must be switched each time.
#
# xone does NOT support racing wheels — it grabs the c26d device, gets stuck
# in gip_handle_pkt_identify, and blocks the mode switch. We blacklist its
# modules so the udev rule below can run usb_modeswitch cleanly.
#
# Steam note: the wheel will NOT appear in Steam's "Detected Controllers"
# list. That list is for gamepads Steam Input can remap. Wheels are exposed
# to games directly as SDL joysticks (visible in Settings → Controller →
# "Test Device Inputs"). In-game controls work normally. Don't chase this.

set -euo pipefail

echo "=== lsusb: Logitech devices ==="
lsusb | grep -i "046d:" || echo "(no Logitech USB devices found)"
echo

echo "=== /proc/bus/input/devices: wheel entries ==="
awk 'BEGIN{RS="";ORS="\n\n"} /046d:C29[4-D]|046d:C26[6D]|G923|G29|G27|G25|G920|DFGT|Driving Force|Wheel/{print}' \
    /proc/bus/input/devices \
    || echo "(no wheel input device registered — kernel driver is not binding)"
echo

echo "=== Loaded wheel/xbox-pad kernel modules ==="
lsmod | grep -E "hid_logitech|hid_logitech_hidpp|new_lg4ff|xpad|xone|xpadneo" \
    || echo "(none loaded)"
echo

echo "=== Recent dmesg for the wheel ==="
sudo dmesg 2>/dev/null | grep -iE "046d|c26d|c266|g923|logitech|xone|xpad" | tail -20 \
    || echo "(no relevant dmesg entries)"
echo

echo "=== Driver install ==="
sudo pacman -S --needed linux-headers joyutils usb_modeswitch
yay -S --needed oversteer game-devices-udev

echo
echo "=== Blacklist xone (it cannot drive racing wheels) ==="
sudo tee /etc/modprobe.d/blacklist-xone.conf >/dev/null <<'EOF'
# xone grabs the G923 Xbox variant (046d:c26d) and leaves it stuck in
# gip_handle_pkt_identify. It has no support for racing wheels. Blacklist so
# the wheel can be flipped to HID++ mode and bound by hid-logitech-hidpp.
blacklist xone_wired
blacklist xone_gip
blacklist xone_dongle
EOF

sudo modprobe -r xone_wired xone_gip xone_dongle 2>/dev/null || true

echo
echo "=== Install udev rule for usb_modeswitch ==="
sudo tee /etc/udev/rules.d/99-logitech-g923-wheel.rules >/dev/null <<'EOF'
# Logitech G923 Racing Wheel for Xbox One / PC (046d:c26d).
# Flip out of Xbox compat mode into HID++ on every plug-in so
# hid-logitech-hidpp can bind. Canonical command from the ArchWiki.
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c26d", RUN+="/usr/bin/usb_modeswitch -v 046d -p c26d -M 0f00010142 -C 0x03 -m 01 -r 81"
EOF

sudo udevadm control --reload-rules

# Trigger the switch now for the currently-connected wheel (no replug needed).
if lsusb | grep -q "046d:c26d"; then
    echo
    echo "=== Running usb_modeswitch on currently-connected wheel ==="
    sudo usb_modeswitch -v 046d -p c26d -M 0f00010142 -C 0x03 -m 01 -r 81 || true
fi

echo
echo "Wheel should now appear in /proc/bus/input/devices within a second or two."
echo "Re-run this script to verify."
