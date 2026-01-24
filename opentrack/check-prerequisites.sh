#!/bin/bash

# OpenTrack Docker Prerequisites Check Script
# This script verifies that all requirements are met before running opentrack

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "OpenTrack Docker Prerequisites Checker"
echo "========================================"
echo

# Check 1: Docker is installed
echo -n "Checking Docker installation... "
if command -v docker &> /dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check 2: Docker Compose is installed
echo -n "Checking Docker Compose... "
if docker compose version &> /dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    echo "Docker Compose is not available. Please ensure Docker Compose v2 is installed."
    exit 1
fi

# Check 3: X11 display is available
echo -n "Checking X11 display... "
if [ -z "$DISPLAY" ]; then
    echo -e "${RED}FAILED${NC}"
    echo "DISPLAY environment variable is not set. Are you running a graphical session?"
    exit 1
else
    echo -e "${GREEN}OK${NC} (DISPLAY=$DISPLAY)"
fi

# Check 4: X11 socket exists
echo -n "Checking X11 socket... "
if [ -d "/tmp/.X11-unix" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}WARNING${NC}"
    echo "X11 socket directory does not exist at /tmp/.X11-unix"
fi

# Check 5: xhost permissions
echo -n "Checking xhost permissions... "
if command -v xhost &> /dev/null; then
    # Check if local connections are allowed
    if xhost | grep -q "LOCAL:"; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}WARNING${NC}"
        echo "X11 access may not be allowed. Run: xhost +local:docker"
        echo "This allows Docker containers to display GUI applications."
    fi
else
    echo -e "${YELLOW}WARNING${NC}"
    echo "xhost command not found. You may need to run: xhost +local:docker"
fi

# Check 6: Webcam device exists
echo -n "Checking webcam device... "
if [ -e "/dev/video0" ]; then
    echo -e "${GREEN}OK${NC}"
    ls -l /dev/video0
else
    echo -e "${RED}FAILED${NC}"
    echo "Webcam device /dev/video0 not found."
    echo "Available video devices:"
    ls -l /dev/video* 2>/dev/null || echo "  No video devices found"
    echo
    echo "If your webcam is at a different path, edit docker-compose.yml"
    exit 1
fi

# Check 7: User is in video group (optional)
echo -n "Checking video group membership... "
if groups | grep -q video; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}WARNING${NC}"
    echo "You are not in the 'video' group. This may cause permission issues."
    echo "To add yourself: sudo usermod -a -G video $USER"
    echo "Then log out and back in for changes to take effect."
fi

# Check 8: Docker image exists
echo -n "Checking Docker image... "
if docker images | grep -q "opentrack-opentrack"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}NOT BUILT${NC}"
    echo "Docker image not found. Run: docker compose build"
fi

echo
echo "========================================"
echo -e "${GREEN}Prerequisites check complete!${NC}"
echo
echo "To build the image:"
echo "  docker compose build"
echo
echo "To run opentrack:"
echo "  xhost +local:docker  # If not already done"
echo "  docker compose up"
