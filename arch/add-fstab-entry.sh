#!/usr/bin/env bash
set -euo pipefail

# Add an fstab entry for a device, matching the existing comment + entry style.
# Usage: sudo ./add-fstab-entry.sh /dev/sdX1 /mnt/my-drive [options]
#
# Examples:
#   sudo ./add-fstab-entry.sh /dev/sda1 /mnt/big-flash-drive
#   sudo ./add-fstab-entry.sh /dev/sda1 /mnt/big-flash-drive "defaults,nofail"

if [[ $EUID -ne 0 ]]; then
    echo "Error: must run as root (sudo)" >&2
    exit 1
fi

if [[ $# -lt 2 ]]; then
    echo "Usage: sudo $0 <device> <mountpoint> [options]" >&2
    echo "  device      e.g. /dev/sda1" >&2
    echo "  mountpoint  e.g. /mnt/big-flash-drive" >&2;
    echo "  options     mount options (default: defaults,nofail)" >&2
    exit 1
fi

DEVICE="$1"
MOUNTPOINT="$2"
OPTIONS="${3:-defaults,nofail}"

# Resolve device info
if ! blkid "$DEVICE" &>/dev/null; then
    echo "Error: device $DEVICE not found" >&2
    exit 1
fi

UUID=$(blkid -s UUID -o value "$DEVICE")
FSTYPE=$(blkid -s TYPE -o value "$DEVICE")
LABEL=$(blkid -s LABEL -o value "$DEVICE" || true)

if [[ -z "$UUID" || -z "$FSTYPE" ]]; then
    echo "Error: could not determine UUID or filesystem type for $DEVICE" >&2
    exit 1
fi

# Build the comment line
COMMENT="# $DEVICE"
if [[ -n "$LABEL" ]]; then
    COMMENT="$COMMENT LABEL=$LABEL"
fi

# Pick dump/pass defaults
DUMP=0
PASS=0
if [[ "$MOUNTPOINT" == "/boot"* ]]; then
    PASS=2
elif [[ "$MOUNTPOINT" == "/" ]]; then
    PASS=1
fi

# Format the entry to align with typical fstab columns
ENTRY=$(printf "UUID=%-36s %-15s %-15s %-s %d %d" \
    "$UUID" "$MOUNTPOINT" "$FSTYPE" "$OPTIONS" "$DUMP" "$PASS")

# Create mount point if needed
mkdir -p "$MOUNTPOINT"

# Preview and confirm
echo ""
echo "Will append to /etc/fstab:"
echo ""
echo "$COMMENT"
echo "$ENTRY"
echo ""
read -rp "Continue? [y/N] " confirm
if [[ "$confirm" != [yY] ]]; then
    echo "Aborted."
    exit 0
fi

# Append
printf "\n%s\n%s\n" "$COMMENT" "$ENTRY" >> /etc/fstab

echo "Entry added. Testing with mount -a..."
if mount -a; then
    echo "Success — $DEVICE mounted at $MOUNTPOINT"
else
    echo "Warning: mount -a failed. Check /etc/fstab for errors." >&2
    exit 1
fi
