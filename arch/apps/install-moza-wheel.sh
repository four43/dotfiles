#!/bin/bash

# https://github.com/JacKeTUs/linux-steering-wheels
# https://github.com/JacKeTUs/universal-pidff
# https://github.com/Lawstorant/boxflat
#
# Moza R12 V2 base + KS Pro Wheel on Linux.
#
# Driver: hid-universal-pidff is upstream since kernel 6.15 (also backported
# to 6.12.24, 6.13.12, 6.14.3). On a modern Arch kernel this is plug-and-play —
# no DKMS module needed. If stuck on an older kernel, install
# universal-pidff-dkms-git from the AUR as a fallback.
#
# The base exposes two USB interfaces under vendor 346e:
#   - HID gamepad   -> picked up by hid-universal-pidff for input + FFB
#   - ttyACM serial -> used by Boxflat to read/write base, wheel, pedal, and
#                      shifter settings (firmware does NOT talk over HID)
#
# Boxflat replaces the Windows-only MOZA Pit House app. It also applies a
# "detection fix" that creates a virtual device so games see all axes/buttons.
#
# KS Pro Wheel plugs into the base via the QR — it does not enumerate as its
# own USB device. Wheel LEDs / display / button mapping are configured through
# Boxflat once the base is talking.
#
# Steam note: like the G923, the wheel will NOT appear in Steam's "Detected
# Controllers" list (that list is for Steam Input gamepads). Games see it
# directly as an SDL joystick — check Settings -> Controller -> "Test Device
# Inputs" if you want to verify.

set -euo pipefail

MOZA_VID="346e"

echo "=== lsusb: Moza devices ==="
lsusb | grep -i "${MOZA_VID}:" || echo "(no Moza USB devices found — is the base powered on and connected?)"
echo

echo "=== /proc/bus/input/devices: wheel entries ==="
awk -v vid="${MOZA_VID^^}" \
    'BEGIN{RS="";ORS="\n\n"} $0 ~ ("Vendor=" tolower(vid)) || /MOZA|R12|R9|R5|R3|R16|R21|KS/ {print}' \
    /proc/bus/input/devices \
    || echo "(no Moza input device registered — kernel driver is not binding)"
echo

echo "=== Loaded HID / PIDFF kernel modules ==="
lsmod | grep -E "hid_generic|hid_pidff|hid_universal_pidff" \
    || echo "(none loaded yet — will load on first connect)"
echo

echo "=== Kernel version ==="
uname -r
echo "(hid-universal-pidff is upstream since 6.15; 6.12.24 / 6.13.12 / 6.14.3 backports also carry it)"
echo

echo "=== Recent dmesg for the wheel ==="
sudo dmesg 2>/dev/null | grep -iE "${MOZA_VID}|moza|pidff|hid-generic" | tail -20 \
    || echo "(no relevant dmesg entries)"
echo

echo "=== Driver install ==="
sudo pacman -S --needed joyutils
yay -S --needed boxflat-git game-devices-udev

echo
echo "=== Install udev rule for Moza serial config channel ==="
# Boxflat talks to the base over /dev/ttyACM*. Without this rule only root can
# open it, so the app cannot read or write settings. TAG+="uaccess" hands
# ownership to the logged-in seat user via systemd-logind.
sudo tee /etc/udev/rules.d/99-moza-wheel.rules >/dev/null <<EOF
# Moza Racing wheelbases (vendor 346e) — grant user access to the serial
# config endpoint so Boxflat can configure base/wheel/pedals/shifters.
SUBSYSTEM=="tty", KERNEL=="ttyACM*", ATTRS{idVendor}=="${MOZA_VID}", ACTION=="add", MODE="0666", TAG+="uaccess"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=tty --action=add

echo
if lsusb | grep -qi "${MOZA_VID}:"; then
    echo "Base detected. Launch Boxflat from your app menu (or run 'boxflat') to"
    echo "configure FFB strength, wheel LEDs/display, pedal calibration, etc."
else
    echo "Base not detected. Power on the R12 V2, connect the USB cable, and"
    echo "re-run this script to verify."
fi
