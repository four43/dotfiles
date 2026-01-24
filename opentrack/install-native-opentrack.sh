#!/bin/bash
set -e

# Install Native OpenTrack with Wine Support
# This script builds OpenTrack from source with Wine protocol enabled

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

info "Installing native OpenTrack with Wine support..."

# Install dependencies
info "Installing build dependencies..."
sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    git \
    wget \
    libopencv-dev \
    libproc2-dev \
    qt6-base-private-dev \
    qt6-tools-dev \
    libqt6gui6 \
    libqt6widgets6 \
    v4l-utils \
    wine64 \
    wine32 \
    || warn "Some packages may not be available, continuing..."

# Download ONNX Runtime for neural net tracker
info "Downloading ONNX Runtime..."
cd /tmp
if [ ! -d "/tmp/onnxruntime-linux-x64-1.23.2" ]; then
    wget -q https://github.com/microsoft/onnxruntime/releases/download/v1.23.2/onnxruntime-linux-x64-1.23.2.tgz
    tar -xzf onnxruntime-linux-x64-1.23.2.tgz
fi

export ONNXRuntime_DIR=/tmp/onnxruntime-linux-x64-1.23.2

# Clone OpenTrack
info "Cloning OpenTrack..."
if [ -d "/tmp/opentrack" ]; then
    rm -rf /tmp/opentrack
fi
git clone https://github.com/opentrack/opentrack.git /tmp/opentrack
cd /tmp/opentrack

# Build with Wine support enabled
info "Building OpenTrack with Wine support (this may take a few minutes)..."
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DSDK_WINE=ON \
    -DONNXRuntime_DIR=${ONNXRuntime_DIR}

cd build
make -j$(nproc)

# Install to /opt/opentrack
info "Installing OpenTrack..."
sudo make install

info "Creating desktop launcher..."
cat > ~/.local/share/applications/opentrack.desktop <<EOF
[Desktop Entry]
Name=OpenTrack (Native with Wine)
Comment=Head tracking software with Wine support
Exec=/usr/local/bin/opentrack
Icon=opentrack
Terminal=false
Type=Application
Categories=Utility;
EOF

# Create a simple wrapper script for the Wine prefix
info "Creating Wine prefix configuration helper..."
cat > ~/opentrack-wine-setup.sh <<'EOF'
#!/bin/bash

# OpenTrack Wine Prefix Configuration Helper
# Run this to configure OpenTrack to inject into a specific game's Wine prefix

GAME_APPID="2168680"  # Nuclear Option
STEAM_LIBRARY="/mnt/0dd74c4a-4e76-45d6-9fc5-d1b2ea1b9255/steam/SteamLibrary"
WINEPREFIX="$STEAM_LIBRARY/steamapps/compatdata/$GAME_APPID/pfx"

echo "Wine Prefix Configuration"
echo "========================="
echo ""
echo "Your Nuclear Option Wine prefix is at:"
echo "  $WINEPREFIX"
echo ""
echo "To use OpenTrack with Nuclear Option:"
echo ""
echo "1. Start OpenTrack: opentrack"
echo "2. Set Input: NeuralNet head pose estimator"
echo "3. Set Output: 'Wine — Windows layer for Unix'"
echo "4. Click the settings icon next to Output"
echo "5. Set Wine variant: Wine"
echo "6. Set Wine prefix path:"
echo "   $WINEPREFIX"
echo "7. Click OK, then Start tracking"
echo "8. Launch Nuclear Option from Steam"
echo ""
echo "The registry entries will be automatically injected into the game!"
EOF

chmod +x ~/opentrack-wine-setup.sh

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Native OpenTrack with Wine Support Installed!       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Run the configuration helper to see setup instructions:"
echo "   ~/opentrack-wine-setup.sh"
echo ""
echo "2. Start OpenTrack:"
echo "   opentrack"
echo ""
echo "3. You can now uninstall the Docker version if you want:"
echo "   cd ~/projects/four43/dotfiles/opentrack"
echo "   docker compose down"
echo ""
