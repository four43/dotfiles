#!/bin/bash
set -e

# TrackIR/FreeTrack Setup Script for Nuclear Option (Linux + Proton)
# This script automates the setup of OpenTrack for Steam Proton games

# Configuration
GAME_NAME="Nuclear Option"
APPID="2168680"
OPENTRACK_VERSION="2023.3.0"
OPENTRACK_URL="https://github.com/opentrack/opentrack/releases/download/opentrack-${OPENTRACK_VERSION}/opentrack-${OPENTRACK_VERSION}-win32-portable.7z"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check dependencies
check_dependencies() {
    local missing_deps=()

    for cmd in wget 7za; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing_deps[*]}\nInstall with: sudo apt install wget p7zip-full"
    fi

    # Check for 32-bit library support (required for Wine/Proton)
    if [ ! -f /lib/ld-linux.so.2 ] && [ ! -f /lib32/ld-linux.so.2 ]; then
        warn "32-bit library support not detected!"
        warn "Proton requires 32-bit libraries to run Windows applications."
        warn ""
        warn "To fix this, run:"
        warn "  sudo dpkg --add-architecture i386"
        warn "  sudo apt update"
        warn "  sudo apt install libc6:i386 libstdc++6:i386 libfreetype6:i386"
        warn ""
        warn "After installing, re-run this script."
        error "32-bit library support required"
    fi

    # Check for FreeType (needed for Wine fonts)
    if ! dpkg -l | grep -q "libfreetype6:i386"; then
        warn "FreeType font library not detected (libfreetype6:i386)"
        warn "Wine needs FreeType to render fonts properly."
        warn ""
        warn "To install, run:"
        warn "  sudo apt install libfreetype6:i386"
        echo ""
    fi
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    cat <<EOF
Usage: $0 <steam-game-path>

Example:
  $0 "/mnt/0dd74c4a-4e76-45d6-9fc5-d1b2ea1b9255/steam/SteamLibrary/steamapps/common/Nuclear Option"

This script will:
  1. Download Windows OpenTrack portable
  2. Extract it to the Proton prefix
  3. Create a launcher script for easy use
  4. Display configuration instructions

EOF
    exit 1
fi

GAME_PATH="$1"

# Validate game path
if [ ! -d "$GAME_PATH" ]; then
    error "Game directory not found: $GAME_PATH"
fi

info "Game directory: $GAME_PATH"

# Derive steamapps path
STEAMAPPS_DIR=$(dirname "$GAME_PATH")
info "Steamapps directory: $STEAMAPPS_DIR"

# Find compatdata directory
COMPATDATA_DIR="$(dirname "$STEAMAPPS_DIR")/compatdata/$APPID"
if [ ! -d "$COMPATDATA_DIR" ]; then
    error "Compatdata directory not found: $COMPATDATA_DIR\nMake sure you've launched $GAME_NAME at least once."
fi

WINEPREFIX="$COMPATDATA_DIR/pfx"
info "Wine prefix: $WINEPREFIX"

# Find Proton installation
STEAM_ROOT=$(dirname "$(dirname "$STEAMAPPS_DIR")")

# Find the newest/latest Proton version available
info "Searching for Proton installations..."

# Prefer Proton Experimental if available, otherwise find the highest version
PROTON_PATH=""

if [ -d "$STEAM_ROOT/steamapps/common/Proton - Experimental" ] && [ -f "$STEAM_ROOT/steamapps/common/Proton - Experimental/proton" ]; then
    PROTON_PATH="$STEAM_ROOT/steamapps/common/Proton - Experimental"
    info "Found Proton Experimental"
else
    # Find all Proton versions and sort numerically
    while IFS= read -r proton_dir; do
        if [ -d "$proton_dir" ] && [ -f "$proton_dir/proton" ]; then
            PROTON_PATH="$proton_dir"
            info "  Found: $(basename "$proton_dir")"
        fi
    done < <(find "$STEAM_ROOT/steamapps/common" -maxdepth 1 -type d -name "Proton*" | sort -V | tail -1)
fi

if [ -z "$PROTON_PATH" ]; then
    error "Could not find Proton installation in $STEAM_ROOT/steamapps/common/"
fi

info "Using Proton: $(basename "$PROTON_PATH")"

# Check what version the prefix was created with
if [ -f "$COMPATDATA_DIR/version" ]; then
    CURRENT_VERSION=$(head -n1 "$COMPATDATA_DIR/version" | cut -d'-' -f1)
    info "Prefix was created with Proton version: $CURRENT_VERSION"
fi

# Check dependencies
check_dependencies

# Download Windows OpenTrack
info "Downloading Windows OpenTrack ${OPENTRACK_VERSION}..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

if [ ! -f "opentrack-${OPENTRACK_VERSION}-win32-portable.7z" ]; then
    wget -q --show-progress "$OPENTRACK_URL" || error "Failed to download OpenTrack"
fi

# Extract
info "Extracting OpenTrack..."
mkdir -p opentrack-extract
7za x -y -o"opentrack-extract" "opentrack-${OPENTRACK_VERSION}-win32-portable.7z" > /dev/null || error "Failed to extract OpenTrack"

# Copy to Proton prefix
OPENTRACK_INSTALL_DIR="$WINEPREFIX/drive_c/opentrack"
info "Installing to: $OPENTRACK_INSTALL_DIR"

rm -rf "$OPENTRACK_INSTALL_DIR"
cp -r "$TEMP_DIR/opentrack-extract/install" "$OPENTRACK_INSTALL_DIR" || error "Failed to copy OpenTrack to prefix"

# Create launcher script
LAUNCHER_SCRIPT="$GAME_PATH/launch-with-tracking.sh"
info "Creating launcher script: $LAUNCHER_SCRIPT"

cat > "$LAUNCHER_SCRIPT" <<'LAUNCHER_EOF'
#!/bin/bash

# TrackIR Launcher for Nuclear Option
# This script launches Windows OpenTrack in the background before the game

export WINEPREFIX="__WINEPREFIX__"
export STEAM_COMPAT_DATA_PATH="__COMPATDATA__"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="__STEAM_ROOT__"
PROTON_PATH="__PROTON_PATH__"

echo "Starting Windows OpenTrack..."
"$PROTON_PATH/proton" run "$WINEPREFIX/drive_c/opentrack/opentrack.exe" &
OPENTRACK_PID=$!

echo "OpenTrack started (PID: $OPENTRACK_PID)"
echo "Waiting for initialization..."
sleep 3

echo "You can now launch Nuclear Option from Steam"
echo "Press Ctrl+C to stop OpenTrack when done"

# Keep script running
wait $OPENTRACK_PID
LAUNCHER_EOF

# Replace placeholders
sed -i "s|__WINEPREFIX__|$WINEPREFIX|g" "$LAUNCHER_SCRIPT"
sed -i "s|__COMPATDATA__|$COMPATDATA_DIR|g" "$LAUNCHER_SCRIPT"
sed -i "s|__STEAM_ROOT__|$STEAM_ROOT|g" "$LAUNCHER_SCRIPT"
sed -i "s|__PROTON_PATH__|$PROTON_PATH|g" "$LAUNCHER_SCRIPT"
chmod +x "$LAUNCHER_SCRIPT"

# Create configuration helper script
CONFIG_SCRIPT="$GAME_PATH/configure-opentrack.sh"
info "Creating configuration helper: $CONFIG_SCRIPT"

cat > "$CONFIG_SCRIPT" <<'CONFIG_EOF'
#!/bin/bash

# Configure Windows OpenTrack
export WINEPREFIX="__WINEPREFIX__"
export STEAM_COMPAT_DATA_PATH="__COMPATDATA__"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="__STEAM_ROOT__"
export WINEDEBUG=-all  # Suppress excessive wine debug output
PROTON_PATH="__PROTON_PATH__"

# Check if DISPLAY is set (required for GUI)
if [ -z "$DISPLAY" ]; then
    echo "Error: DISPLAY environment variable not set"
    echo "You need to run this from a graphical session"
    exit 1
fi

echo "Launching Windows OpenTrack for configuration..."
echo ""
echo "Configure the following settings:"
echo ""
echo "INPUT (Tracker):"
echo "  - Select: 'UDP over network'"
echo "  - Settings:"
echo "    * Port: 4242"
echo "    * Add loopback: [✓] CHECKED"
echo ""
echo "OUTPUT (Protocol):"
echo "  - Select: 'freetrack 2.0 Enhanced'"
echo "  - Leave default settings"
echo ""
echo "Then SAVE (don't click Start) and close OpenTrack"
echo ""
echo "Debug info:"
echo "  DISPLAY: $DISPLAY"
echo "  OpenTrack: $WINEPREFIX/drive_c/opentrack/opentrack.exe"
echo ""

# Check if opentrack.exe exists
if [ ! -f "$WINEPREFIX/drive_c/opentrack/opentrack.exe" ]; then
    echo "Error: opentrack.exe not found at expected location"
    echo "Please run the setup script again"
    exit 1
fi

# List opentrack directory contents
echo "OpenTrack directory contents:"
ls -la "$WINEPREFIX/drive_c/opentrack/" | head -10
echo ""

# Enable verbose logging if PROTON_LOG is set
if [ -n "$PROTON_LOG" ]; then
    export PROTON_LOG=1
    export PROTON_LOG_DIR=/tmp
    echo "Verbose logging enabled. Logs will be in /tmp"
    echo ""
fi

# Try running with --version first to test
echo "Testing OpenTrack executable..."
timeout 5 "$PROTON_PATH/proton" run "$WINEPREFIX/drive_c/opentrack/opentrack.exe" --version 2>&1 || true
echo ""

# Now run normally
echo "Starting OpenTrack GUI..."
"$PROTON_PATH/proton" run "$WINEPREFIX/drive_c/opentrack/opentrack.exe" 2>&1 | tee /tmp/opentrack-config.log &
OPENTRACK_PID=$!

# Wait a bit and check if the process is still running
sleep 3
if ! ps -p $OPENTRACK_PID > /dev/null 2>&1; then
    echo ""
    echo "WARNING: OpenTrack process exited immediately"
    echo "Log saved to: /tmp/opentrack-config.log"
    echo ""
    echo "Possible causes:"
    echo "  1. Missing Qt libraries (try: sudo apt install libqt5widgets5:i386 libqt5gui5:i386 libqt5core5a:i386)"
    echo "  2. Missing OpenCV libraries"
    echo "  3. Configuration file issues"
    echo ""
    echo "To get detailed logs, run:"
    echo "  PROTON_LOG=1 $0"
    echo ""
    echo "Or try running Steam's Nuclear Option once to ensure Proton is fully set up."
    exit 1
fi

# Wait for the process
wait $OPENTRACK_PID
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "OpenTrack exited with code $EXIT_CODE"
    echo "Log saved to: /tmp/opentrack-config.log"
fi
CONFIG_EOF

sed -i "s|__WINEPREFIX__|$WINEPREFIX|g" "$CONFIG_SCRIPT"
sed -i "s|__COMPATDATA__|$COMPATDATA_DIR|g" "$CONFIG_SCRIPT"
sed -i "s|__STEAM_ROOT__|$STEAM_ROOT|g" "$CONFIG_SCRIPT"
sed -i "s|__PROTON_PATH__|$PROTON_PATH|g" "$CONFIG_SCRIPT"
chmod +x "$CONFIG_SCRIPT"

# Cleanup
rm -rf "$TEMP_DIR"

# Print success message and instructions
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  Installation Complete!                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo -e "${GREEN}1. Configure Windows OpenTrack (ONE TIME ONLY):${NC}"
echo "   Run this script to configure the Windows OpenTrack instance:"
echo ""
echo -e "   ${YELLOW}$CONFIG_SCRIPT${NC}"
echo ""
echo -e "${GREEN}2. Start Docker OpenTrack (EVERY TIME):${NC}"
echo "   Before playing, start your Docker OpenTrack:"
echo ""
echo "   cd ~/projects/four43/dotfiles/opentrack"
echo "   docker compose up"
echo ""
echo "   Configure Docker OpenTrack:"
echo "   - Input: \"NeuralNet head pose estimator\" (or your tracker)"
echo "   - Output: \"UDP over network\" → IP: 127.0.0.1, Port: 4242"
echo "   - Click \"Start\""
echo ""
echo -e "${GREEN}3. Launch the Game:${NC}"
echo -e "   ${YELLOW}Option A: Manual Launch (Recommended)${NC}"
echo ""
echo "   a) Start Windows OpenTrack:"
echo -e "      ${YELLOW}$LAUNCHER_SCRIPT${NC}"
echo ""
echo "   b) Launch Nuclear Option from Steam normally"
echo ""
echo -e "   ${YELLOW}Option B: Automatic Launch via Steam${NC}"
echo ""
echo "   Right-click Nuclear Option → Properties → Launch Options:"
echo ""
echo -e "   ${YELLOW}bash \"$LAUNCHER_SCRIPT\" & sleep 3; %command%${NC}"
echo ""
echo "   (Make sure Docker OpenTrack is running first!)"
echo ""
echo -e "${GREEN}4. In-Game Setup:${NC}"
echo "   - Go to game Settings/Options"
echo "   - Enable TrackIR/Head Tracking support"
echo "   - Adjust sensitivity as needed"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "   - Test Docker OpenTrack UDP: nc -ul 4242"
echo "   - Check Proton prefix: ls \"$WINEPREFIX/drive_c/opentrack/\""
echo "   - Reconfigure Windows OpenTrack: run the configure script again"
echo ""
echo -e "${GREEN}Files created:${NC}"
echo "   - Launcher: $LAUNCHER_SCRIPT"
echo "   - Config:   $CONFIG_SCRIPT"
echo "   - Install:  $OPENTRACK_INSTALL_DIR"
echo ""
echo -e "${GREEN}Happy flying! ✈️${NC}"
echo ""
