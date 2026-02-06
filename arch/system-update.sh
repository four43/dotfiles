#!/bin/bash
set -e

log() {
    echo "$@" >&2
}

log "=== System Update Script ==="
log

# Create pre-update snapshot with timeshift
log "[1/5] Creating pre-update snapshot with timeshift..."
sudo timeshift --create --comments "pre-update" --scripted

log
log "[2/5] Cleaning old pre-update snapshots (keeping only 5 most recent)..."
# Get list of snapshots with "pre-update" comment, sorted by date (oldest first)
# Timeshift list output format can be parsed to get snapshot names
snapshot_list=$(sudo timeshift --list --scripted | grep -E "^\s*>" | grep "pre-update" | awk '{print $2}' | head -n -5)

if [ -n "$snapshot_list" ]; then
    while IFS= read -r snapshot; do
        log "Deleting old snapshot: $snapshot"
        sudo timeshift --delete --snapshot "$snapshot" --scripted
    done <<< "$snapshot_list"
else
    log "No old snapshots to delete (5 or fewer exist)"
fi

log
log "[3/5] Updating pacman packages..."
sudo pacman -Syu --noconfirm

log
log "[4/5] Updating AUR packages with yay..."
yay -Syu --noconfirm

log
log "[5/5] Updating flatpak packages..."
flatpak update -y
log "  Removing unused packages..."
flatpak uninstall --unused -y

log
log "=== System update completed successfully! ==="
