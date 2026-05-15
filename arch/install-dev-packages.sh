#!/bin/bash
set -euo pipefail

# Add smiller to dev/desktop groups (wheel is already granted by install-arch.sh)
sudo usermod -aG docker,video,audio smiller

sudo pacman -S \
	alacritty \
	ark \
	aws-cli-v2 \
	base-devel \
	bluez \
	docker \
	docker-compose \
	docker-buildx \
	git-lfs \
	github-cli \
	kwallet \
	kwallet-pam \
	openrgb \
	nodejs \
	otf-monaspace-nerd \
	python \
	python-click \
	python-ipykernel \
	python-pandas \
	python-pip \
	python-requests \
	shfmt \
	ttf-dejavu-nerd \
	ttf-opensans \
	ttf-noto-nerd \
	noto-fonts-emoji \
	uv \
	&& echo "Installed dev tools"

# Install yay
mkdir -p ~/opt
cd ~/opt
rm -rf ~/opt/yay || true
git clone https://aur.archlinux.org/yay.git yay
cd yay
makepkg -si --noconfirm

yay -S \
	konsave \
	tmux-plugin-manager \
	visual-studio-code-bin

# Bluetooth
systemctl --user enable bluetooth.service
systemctl --user start bluetooth.service

flatpak install \
	com.brave.Browser \
	com.discordapp.Discord \
	com.slack.Slack \
	com.spotify.Client \
	org.gimp.GIMP \
	org.kde.kwrite \
	org.qgis.qgis \
	&& echo "Installed flatpaks" >&2
