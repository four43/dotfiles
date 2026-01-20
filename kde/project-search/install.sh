#!/bin/bash
#
# Install script for KRunner Project Searcher Plugin
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DBUS_SERVICES_DIR="$HOME/.local/share/dbus-1/services"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

# Detect Plasma version and use appropriate directory
if command -v plasmashell &>/dev/null; then
    PLASMA_VERSION=$(plasmashell --version 2>/dev/null | grep -oP '\d+' | head -n1)
    if [ "$PLASMA_VERSION" = "6" ]; then
        KRUNNER_SERVICES_DIR="$HOME/.local/share/kservices6"
        echo "Detected Plasma 6 - using kservices6"
    else
        KRUNNER_SERVICES_DIR="$HOME/.local/share/kservices5"
        echo "Detected Plasma 5 - using kservices5"
    fi
else
    # Default to Plasma 5
    KRUNNER_SERVICES_DIR="$HOME/.local/share/kservices5"
    echo "Could not detect Plasma version - defaulting to kservices5"
fi

echo "Installing KRunner Project Searcher Plugin..."

# Check for required Python packages
echo "Checking Python dependencies..."
if ! python3 -c "import dbus" 2>/dev/null; then
    echo "Error: python-dbus is not installed"
    echo "Install it with: sudo pacman -S python-dbus (Arch) or sudo apt install python3-dbus (Debian/Ubuntu)"
    exit 1
fi

if ! python3 -c "import gi" 2>/dev/null; then
    echo "Error: python-gobject is not installed"
    echo "Install it with: sudo pacman -S python-gobject (Arch) or sudo apt install python3-gi (Debian/Ubuntu)"
    exit 1
fi

echo "✓ Python dependencies satisfied"

# Create necessary directories
echo "Creating directories..."
mkdir -p "$DBUS_SERVICES_DIR"
mkdir -p "$SYSTEMD_USER_DIR"
mkdir -p "$KRUNNER_SERVICES_DIR"

# Make the Python script executable
echo "Making Python script executable..."
chmod +x "$SCRIPT_DIR/project-searcher.py"

# Copy DBus service file
echo "Installing DBus service file..."
cp "$SCRIPT_DIR/org.kde.runner.projectsearcher.service" "$DBUS_SERVICES_DIR/"

# Copy KRunner desktop file
echo "Installing KRunner service descriptor..."
cp "$SCRIPT_DIR/plasma-runner-projectsearcher.desktop" "$KRUNNER_SERVICES_DIR/"

# Copy systemd service file
echo "Installing systemd service file..."
cp "$SCRIPT_DIR/project-searcher.service" "$SYSTEMD_USER_DIR/"

# Reload systemd user daemon
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

# Enable and start the service
echo "Enabling and starting service..."
systemctl --user enable project-searcher.service
systemctl --user restart project-searcher.service

# Wait a moment for the service to start
sleep 2

# Check service status
if systemctl --user is-active --quiet project-searcher.service; then
    echo "✓ Service is running"
else
    echo "⚠ Service failed to start. Check status with: systemctl --user status project-searcher"
    systemctl --user status project-searcher.service --no-pager || true
fi

# Restart KRunner to detect the new plugin
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
echo "Installation complete!"
echo "=========================================="
echo ""
echo "Usage:"
echo "  1. Open KRunner (Alt+Space or Alt+F2)"
echo "  2. Type: project <search term>"
echo "  3. Select a project and press Enter"
echo ""
echo "Service status:"
echo "  systemctl --user status project-searcher"
echo ""
echo "Logs:"
echo "  journalctl --user -u project-searcher -f"
echo ""
