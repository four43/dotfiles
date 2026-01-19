#!/bin/bash
set -euo pipefail

# Install yay
mkdir -p ~/opt
cd ~/opt
rm -rf ~/opt/yay || true
git clone https://aur.archlinux.org/yay.git yay
cd yay
makepkg -si --noconfirm

sudo pacman -S \
	aws-cli-v2 \
	base-devel \
    docker \
    git \
	inetutils \
    openssh \
	python \
    timeshift \
    && echo "Installed dev tools"

yay -S visual-studio-code-bin
