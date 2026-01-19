#!/bin/bash
set -e
VERSION="v3.4.0"
FONT_DIR="/usr/share/fonts/truetype/dejavu-sans-mono-nerd-font"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${VERSION}/DejaVuSansMono.zip"

# Check if font is already installed
if [ -f "$FONT_DIR/other.ttf" ]; then
    echo "DejaVu Sans Mono Nerd Font is already installed"
    exit 0
fi

echo "Installing DejaVu Sans Mono Nerd Font..."

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap 'rm -rf $TMP_DIR' EXIT

# Create font directory
sudo mkdir -p "$FONT_DIR"

# Download and extract font
echo "Downloading font..."
cd "$TMP_DIR"
curl -L -o DejaVuSansMono.zip "$FONT_URL"
unzip -q DejaVuSansMono.zip

# Move fonts to system directory
echo "Installing fonts..."
sudo cp -r ./* "$FONT_DIR/"
sudo chmod -R 755 "$FONT_DIR"

# Update font cache
fc-cache -f

echo "DejaVu Sans Mono Nerd Font installed successfully!"
