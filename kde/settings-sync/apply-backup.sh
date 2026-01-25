#!/bin/bash
set -euo pipefail

PROFILE="home-main"
EXPORT_DIR="$HOME/.dotfiles/kde/settings-backups"

echo "Step 1: Importing '$PROFILE'..."
# -f (force) overwrites the profile if it already exists
konsave -i "$EXPORT_DIR/${PROFILE}.knsv"

echo "Step 2: Apply profile"
# Official command: konsave -e <profile_name>
konsave -a "$PROFILE"

echo "Note: Icons are NOT in the backup. The config points to them, so just reinstall them via your package manager on the new machine."