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
	coreutils \
	docker \
	docker-compose \
	docker-buildx \
	fzf \
	git \
	git-lfs \
	inetutils \
	jq \
	keychain \
	openssh \
	python \
	shfmt \
	timeshift \
	ttf-opensans &&
	echo "Installed dev tools"

# Copy keychain systemd service
mkdir -p ~/.config/systemd/user
cp -f ~/projects/four43/dotfiles/arch/.config/systemd/user/keychain.service ~/.config/systemd/user/

# Enable keychain service to start on login
systemctl --user enable keychain.service
systemctl --user daemon-reload

yay -S visual-studio-code-bin
