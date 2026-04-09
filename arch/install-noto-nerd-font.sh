#!/bin/bash
set -e
VERSION="v3.4.0"
NERD_FONT_DIR="/usr/share/fonts/truetype/noto-nerd-font"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${VERSION}/Noto.zip"
NOTO_DIR="/usr/share/fonts/noto"

# Nerd Font: keep popular weights only (skip Condensed, Propo, Thin, ExtraLight, ExtraBold, Black)
NERD_KEEP='^(LICENSE_OFL\.txt|Noto(Sans|Serif|SansM|Mono)NerdFont(Mono)?-(Regular|Bold|Italic|BoldItalic|Medium|MediumItalic|SemiBold|SemiBoldItalic|Light|LightItalic)\.ttf)$'

# Base Noto: keep English/Latin, Symbols, Math, Emoji (skip all language-specific scripts)
NOTO_KEEP='^Noto(Sans|Serif|Mono|Color)(Display|Symbols|Symbols2|Math)?[-.]'

### Install Noto Nerd Font ###

if [ -f "$NERD_FONT_DIR/NotoSansMNerdFontMono-Regular.ttf" ]; then
    echo "Noto Nerd Font is already installed"
else
    echo "Installing Noto Nerd Font..."

    TMP_DIR=$(mktemp -d)
    trap 'rm -rf $TMP_DIR' EXIT

    sudo mkdir -p "$NERD_FONT_DIR"

    echo "Downloading font..."
    cd "$TMP_DIR"
    curl -L -o Noto.zip "$NERD_FONT_URL"
    unzip -q Noto.zip

    echo "Installing fonts..."
    for f in *; do
        if echo "$f" | grep -qE "$NERD_KEEP"; then
            sudo cp "$f" "$NERD_FONT_DIR/"
        fi
    done
    sudo chmod -R 755 "$NERD_FONT_DIR"
fi

### Clean up Nerd Font directory ###

if [ -d "$NERD_FONT_DIR" ]; then
    NERD_REMOVED=0
    for f in "$NERD_FONT_DIR"/*; do
        BASENAME=$(basename "$f")
        if ! echo "$BASENAME" | grep -qE "$NERD_KEEP"; then
            sudo rm "$f"
            NERD_REMOVED=$((NERD_REMOVED + 1))
        fi
    done
    if [ "$NERD_REMOVED" -gt 0 ]; then
        echo "Removed $NERD_REMOVED unwanted Nerd Font files"
    fi
fi

### Clean up base Noto fonts (language-specific scripts) ###
# Note: To put these back, reinstall noto-fonts package
if [ -d "$NOTO_DIR" ]; then
    NOTO_REMOVED=0
    for f in "$NOTO_DIR"/*; do
        BASENAME=$(basename "$f")
        if ! echo "$BASENAME" | grep -qE "$NOTO_KEEP"; then
            sudo rm "$f"
            NOTO_REMOVED=$((NOTO_REMOVED + 1))
        fi
    done
    if [ "$NOTO_REMOVED" -gt 0 ]; then
        echo "Removed $NOTO_REMOVED language-specific Noto font files"
    fi
fi

# Update font cache
fc-cache -f

echo "Done!"
