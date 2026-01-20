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
	docker-compose \
	docker-buildx \
	git \
	inetutils \
	openssh \
	python \
	shfmt \
	timeshift &&
	echo "Installed dev tools"

systemctl --user enable ssh-agent.service

yay -S visual-studio-code-bin
