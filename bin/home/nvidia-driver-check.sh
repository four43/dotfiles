#!/usr/bin/env bash
#
# Check if Flatpak NVIDIA driver version matches the host system version
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get host NVIDIA driver version
get_host_version() {
    if ! command -v nvidia-smi &> /dev/null; then
        echo "ERROR: nvidia-smi not found on host system" >&2
        return 1
    fi

    nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1 | tr -d '[:space:]'
}

# Get Flatpak NVIDIA driver version
get_flatpak_version() {
    if ! command -v flatpak &> /dev/null; then
        echo "ERROR: flatpak not found" >&2
        return 1
    fi

    # Check if NVIDIA Flatpak runtime is installed
    local nvidia_runtime
    nvidia_runtime=$(flatpak list --runtime | grep -i "nvidia" | grep -oP 'org\.freedesktop\.Platform\.GL\S+' | head -n1)

    if [[ -z "$nvidia_runtime" ]]; then
        echo "NONE"
        return 0
    fi

    # Extract version from runtime name (e.g., org.freedesktop.Platform.GL.nvidia-525-105-17)
    echo "$nvidia_runtime" | grep -oP 'nvidia-\K[\d-]+' | tr '-' '.'
}

main() {
    echo "Checking NVIDIA driver versions..."
    echo ""

    # Get versions
    HOST_VERSION=$(get_host_version)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    FLATPAK_VERSION=$(get_flatpak_version)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    # Display versions
    echo "Host NVIDIA driver:    $HOST_VERSION"
    echo "Flatpak NVIDIA driver: $FLATPAK_VERSION"
    echo ""

    # Compare versions
    if [[ "$FLATPAK_VERSION" == "NONE" ]]; then
        echo -e "${YELLOW}WARNING: No NVIDIA Flatpak runtime installed${NC}"
        echo "To install, run:"
        echo "  flatpak install flathub org.freedesktop.Platform.GL.nvidia-\$DRIVER_VERSION"
        exit 2
    elif [[ "$HOST_VERSION" == "$FLATPAK_VERSION" ]]; then
        echo -e "${GREEN}✓ Versions match!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Version mismatch!${NC}"
        echo ""
        echo "To update Flatpak NVIDIA driver, run:"
        echo "  flatpak update org.freedesktop.Platform.GL.nvidia-*"
        echo ""
        echo "Or install the matching version:"
        echo "  flatpak install flathub org.freedesktop.Platform.GL.nvidia-${HOST_VERSION//./\-}"
        exit 1
    fi
}

main "$@"
