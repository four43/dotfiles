#!/bin/bash
#
# Uninstall script for KRunner Project Searcher Plugin
#

set -e

DBUS_SERVICES_DIR="$HOME/.local/share/dbus-1/services"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

# Remove from both possible locations (Plasma 5 and 6)
KRUNNER_SERVICES_DIRS=(
    "$HOME/.local/share/kservices5"
    "$HOME/.local/share/kservices6"
)

echo "Uninstalling KRunner Project Searcher Plugin..."

# Stop and disable the service
if systemctl --user is-enabled project-searcher.service &>/dev/null; then
    echo "Stopping and disabling service..."
    systemctl --user stop project-searcher.service
    systemctl --user disable project-searcher.service
fi

# Remove systemd service file
if [ -f "$SYSTEMD_USER_DIR/project-searcher.service" ]; then
    echo "Removing systemd service file..."
    rm "$SYSTEMD_USER_DIR/project-searcher.service"
fi

# Remove DBus service file
if [ -f "$DBUS_SERVICES_DIR/org.kde.runner.projectsearcher.service" ]; then
    echo "Removing DBus service file..."
    rm "$DBUS_SERVICES_DIR/org.kde.runner.projectsearcher.service"
fi

# Remove KRunner desktop file from all possible locations
for dir in "${KRUNNER_SERVICES_DIRS[@]}"; do
    if [ -f "$dir/plasma-runner-projectsearcher.desktop" ]; then
        echo "Removing KRunner service descriptor from $dir..."
        rm "$dir/plasma-runner-projectsearcher.desktop"
    fi
done

# Reload systemd user daemon
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

# Restart KRunner
echo "Restarting KRunner..."
if command -v kquitapp5 &>/dev/null; then
    kquitapp5 krunner 2>/dev/null || true
    sleep 1
    kstart5 krunner 2>/dev/null &
elif command -v kquitapp6 &>/dev/null; then
    kquitapp6 krunner 2>/dev/null || true
    sleep 1
    kstart krunner 2>/dev/null &
else
    echo "⚠ Could not automatically restart KRunner. Please restart it manually or log out and back in."
fi

echo ""
echo "=========================================="
echo "Uninstallation complete!"
echo "=========================================="
echo ""
echo "The plugin has been removed from your system."
echo ""
