#!/bin/bash
#
# Debug script for KRunner Project Searcher Plugin
#

echo "=================================================="
echo "KRunner Project Searcher - Debug Information"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

# 1. Check systemd service
echo "1. Checking systemd service status..."
if systemctl --user is-active --quiet project-searcher.service; then
    success "Service is running"
    systemctl --user status project-searcher.service --no-pager | head -n 10
else
    error "Service is NOT running"
    echo "   Try: systemctl --user start project-searcher"
fi
echo ""

# 2. Check DBus registration
echo "2. Checking DBus registration..."
if dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames 2>/dev/null | grep -q "org.kde.runner.projectsearcher"; then
    success "DBus service is registered"
else
    error "DBus service is NOT registered"
    echo "   The service might not be running properly"
fi
echo ""

# 3. Check if files exist
echo "3. Checking installed files..."

DBUS_SERVICE="$HOME/.local/share/dbus-1/services/org.kde.runner.projectsearcher.service"
if [ -f "$DBUS_SERVICE" ]; then
    success "DBus service file exists: $DBUS_SERVICE"
else
    error "DBus service file missing: $DBUS_SERVICE"
fi

SYSTEMD_SERVICE="$HOME/.config/systemd/user/project-searcher.service"
if [ -f "$SYSTEMD_SERVICE" ]; then
    success "Systemd service file exists: $SYSTEMD_SERVICE"
else
    error "Systemd service file missing: $SYSTEMD_SERVICE"
fi

# Check for desktop file in multiple possible locations
DESKTOP_LOCATIONS=(
    "$HOME/.local/share/kservices5/plasma-runner-projectsearcher.desktop"
    "$HOME/.local/share/kservices6/plasma-runner-projectsearcher.desktop"
    "$HOME/.local/share/plasma/plasmoids/plasma-runner-projectsearcher.desktop"
)

DESKTOP_FOUND=false
for location in "${DESKTOP_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        success "Desktop file exists: $location"
        DESKTOP_FOUND=true
        break
    fi
done

if [ "$DESKTOP_FOUND" = false ]; then
    warning "Desktop file not found in common locations"
    echo "   Checked:"
    for location in "${DESKTOP_LOCATIONS[@]}"; do
        echo "     - $location"
    done
fi
echo ""

# 4. Check projects directory
echo "4. Checking projects directory..."
PROJECTS_DIR="$HOME/projects"
if [ -d "$PROJECTS_DIR" ]; then
    PROJECT_COUNT=$(find "$PROJECTS_DIR" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | wc -l)
    success "Projects directory exists with $PROJECT_COUNT projects"
    echo "   Sample projects:"
    find "$PROJECTS_DIR" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | head -n 5 | sed 's/^/     /'
else
    warning "Projects directory does not exist: $PROJECTS_DIR"
fi
echo ""

# 5. Check Python dependencies
echo "5. Checking Python dependencies..."
if python3 -c "import dbus" 2>/dev/null; then
    success "python-dbus is installed"
else
    error "python-dbus is NOT installed"
fi

if python3 -c "import gi" 2>/dev/null; then
    success "python-gobject is installed"
else
    error "python-gobject is NOT installed"
fi
echo ""

# 6. Check service logs
echo "6. Recent service logs (last 20 lines)..."
echo "----------------------------------------"
journalctl --user -u project-searcher.service --no-pager -n 20 2>/dev/null || echo "No logs found"
echo ""

# 7. Test DBus communication
echo "7. Testing DBus communication..."
if command -v dbus-send &>/dev/null; then
    echo "   Attempting to call Config method..."
    if dbus-send --session --print-reply \
        --dest=org.kde.runner.projectsearcher \
        /runner \
        org.kde.krunner1.Config 2>&1 | head -n 10; then
        success "DBus communication works"
    else
        error "DBus communication failed"
    fi
else
    warning "dbus-send command not found, skipping test"
fi
echo ""

# 8. KRunner configuration
echo "8. Checking KRunner configuration..."
KRUNNER_CONFIG="$HOME/.config/krunnerrc"
if [ -f "$KRUNNER_CONFIG" ]; then
    success "KRunner config exists: $KRUNNER_CONFIG"
    if grep -q "projectsearcher" "$KRUNNER_CONFIG" 2>/dev/null; then
        echo "   Plugin is mentioned in config:"
        grep "projectsearcher" "$KRUNNER_CONFIG" | sed 's/^/     /'
    else
        warning "Plugin not yet in KRunner config (might need restart)"
    fi
else
    warning "KRunner config not found"
fi
echo ""

# 9. Check KDE/Plasma version
echo "9. Checking KDE/Plasma version..."
if command -v plasmashell &>/dev/null; then
    PLASMA_VERSION=$(plasmashell --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
    echo "   Plasma version: $PLASMA_VERSION"
    if [[ "$PLASMA_VERSION" == 6.* ]]; then
        warning "You're running Plasma 6 - desktop file might need to be in kservices6/"
    fi
fi
echo ""

# 10. Suggestions
echo "=================================================="
echo "Suggested Next Steps:"
echo "=================================================="
echo ""

if ! systemctl --user is-active --quiet project-searcher.service; then
    echo "1. Start the service:"
    echo "   systemctl --user start project-searcher"
    echo ""
fi

echo "2. Restart KRunner:"
echo "   kquitapp5 krunner || kquitapp6 krunner"
echo "   kstart5 krunner || kstart krunner &"
echo ""

echo "3. Check KRunner settings:"
echo "   Open System Settings → Search → KRunner"
echo "   Look for 'Project Searcher' in the plugins list"
echo ""

echo "4. Test manually with dbus-send:"
echo "   dbus-send --session --print-reply \\"
echo "     --dest=org.kde.runner.projectsearcher /runner \\"
echo "     org.kde.krunner1.Match string:'project test'"
echo ""

echo "5. Watch logs in real-time:"
echo "   journalctl --user -u project-searcher -f"
echo ""

echo "6. For Plasma 6, you might need to move the desktop file:"
echo "   mv ~/.local/share/kservices5/plasma-runner-projectsearcher.desktop \\"
echo "      ~/.local/share/kservices6/"
echo ""
