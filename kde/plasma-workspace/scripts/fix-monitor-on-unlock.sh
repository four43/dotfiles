#!/bin/bash
# Monitor for KDE screen unlock events and fix monitor resolution
# Only runs on aurora (desktop with three monitors)

if [[ "$(hostname)" != "aurora" ]]; then
    exit 0
fi

# Function to fix monitor resolutions
fix_monitors() {
    kscreen-doctor output.DP-3.mode.2560x1440@164.80
    kscreen-doctor output.DP-4.mode.2560x1440@164.80
    kscreen-doctor output.DP-5.mode.2560x1440@164.80
}

# Fix on startup
fix_monitors

# Monitor D-Bus for screen unlock events
dbus-monitor --session "type='signal',interface='org.freedesktop.ScreenSaver',member='ActiveChanged'" 2>/dev/null |
while read -r line; do
    if echo "$line" | grep -q "boolean false"; then
        # Screen was unlocked (ActiveChanged to false means unlocked)
        fix_monitors
    fi
done
