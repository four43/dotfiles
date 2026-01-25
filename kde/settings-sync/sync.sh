#!/bin/bash
set -euo pipefail

PROFILE="home-main"
EXPORT_DIR="$HOME/.dotfiles/kde/settings-backups"
mkdir -p "$EXPORT_DIR"

echo "Step 1: Saving current KDE state to profile '$PROFILE'..."
# -f (force) overwrites the profile if it already exists
konsave -s "$PROFILE" -f

echo "Step 2: Exporting profile to .knsv file..."
# Official command: konsave -e <profile_name>
konsave -e "$PROFILE"

# The official tool exports to the home directory by default
# We move it to your dotfiles directory
mv "$PROFILE.knsv" "$EXPORT_DIR/"

echo "✅ Done! Settings saved to $EXPORT_DIR/$PROFILE.knsv"
echo "Note: Icons are NOT in the backup. The config points to them, so just reinstall them via your package manager on the new machine."