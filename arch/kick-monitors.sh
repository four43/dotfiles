#!/bin/bash
# Script to fix monitor detection issues after sleep/resume on NVIDIA+Wayland

echo "Forcing monitor re-detection..."

# Method 1: Use kscreen-doctor to cycle DPMS (Display Power Management)
if command -v kscreen-doctor &> /dev/null; then
    echo "Using kscreen-doctor to reset displays..."
    kscreen-doctor --dpms off
    sleep 2
    kscreen-doctor --dpms on
    echo "Displays reset complete"
else
    echo "kscreen-doctor not found, trying alternative method..."

    # Method 2: Restart KWin compositor
    echo "Restarting KWin compositor..."
    kwin_wayland --replace &
    disown
fi

echo "Monitor kick complete. Check if displays are detected correctly."
