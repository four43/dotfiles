#!/bin/bash
set -e

echo "=== System Update Script ==="
echo

# Create pre-update snapshot with timeshift
echo "[1/5] Creating pre-update snapshot with timeshift..."
sudo timeshift --create --comments "pre-update" --scripted

echo
echo "[2/5] Cleaning old pre-update snapshots (keeping only 5 most recent)..."
# Get list of snapshots with "pre-update" comment, sorted by date (oldest first)
# Timeshift list output format can be parsed to get snapshot names
snapshot_list=$(sudo timeshift --list --scripted | grep -E "^\s*>" | grep "pre-update" | awk '{print $2}' | head -n -5)

if [ -n "$snapshot_list" ]; then
    while IFS= read -r snapshot; do
        echo "Deleting old snapshot: $snapshot"
        sudo timeshift --delete --snapshot "$snapshot" --scripted
    done <<< "$snapshot_list"
else
    echo "No old snapshots to delete (5 or fewer exist)"
fi

echo
echo "[3/5] Updating pacman packages..."
sudo pacman -Syu --noconfirm

echo
echo "[4/5] Updating AUR packages with yay..."
yay -Syu --noconfirm

echo
echo "[5/5] Updating flatpak packages..."
flatpak update -y

echo
echo "=== System update completed successfully! ==="
