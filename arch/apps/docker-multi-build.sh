#!/bin/bash
# Set up Docker with multi-platform build support on Arch Linux
# Installs Docker, buildx, and QEMU for cross-architecture emulation

set -e

echo "--- Installing Docker and QEMU packages ---"
sudo pacman -S --needed docker docker-buildx qemu-user-static qemu-user-static-binfmt

echo "--- Enabling and starting Docker ---"
sudo systemctl enable --now docker

echo "--- Restarting binfmt to register QEMU handlers ---"
sudo systemctl restart systemd-binfmt

echo "--- Adding current user to docker group ---"
sudo usermod -aG docker "$USER"

echo "--- Creating multi-platform buildx builder ---"
# newgrp runs the command in a subshell with the docker group active,
# avoiding a full re-login.
newgrp docker <<EOF
docker buildx create --name multiplatform --driver docker-container --bootstrap --use
echo "--- Verifying builder ---"
docker buildx inspect --bootstrap
EOF

echo "--- Success! ---"
echo "You may need to log out and back in for the docker group to take effect everywhere."
echo "Test with: docker buildx build --platform linux/amd64,linux/arm64 -t test:latest ."
