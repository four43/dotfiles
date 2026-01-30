#!/bin/bash
set -euo pipefail

# Ensure user smiller is in groups docker video audio and wheel
sudo usermod -aG docker,video,audio,wheel smiller

# In order to clone the repo you will probably need git and openssh

# Configure sources automatically
echo "[Sources List] --- Installing Reflector ---" >&2
sudo pacman -Sy --needed reflector --noconfirm

echo "[Sources List] --- Backing up current mirrorlist ---" >&2
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

echo "[Sources List] --- Optimizing mirrors for the US (Top 10 fastest, HTTPS) ---" >&2
sudo reflector --country 'United States' \
          --protocol https \
          --latest 20 \
          --sort rate \
          --save /etc/pacman.d/mirrorlist

echo "[Sources List] --- Configuring Weekly Auto-Updates ---" >&2
# Edit the config file for the systemd service
cat <<EOF | sudo tee /etc/xdg/reflector/reflector.conf > /dev/null
--save /etc/pacman.d/mirrorlist
--protocol https
--country 'United States'
--latest 20
--sort rate
EOF

# Enable and start the timer
sudo systemctl enable --now reflector.timer

echo "[Sources List] --- Mirror setup complete! ---" >&2
echo "[Sources List] Your new mirrorlist is ready. Running a database sync..." >&2
sudo pacman -Syy

sudo pacman -S \
	alacritty \
	aws-cli-v2 \
	base-devel \
	bluez \
	coreutils \
	bind \
	docker \
	docker-compose \
	docker-buildx \
	fzf \
	git \
	git-lfs \
	inetutils \
	jq \
	kwallet \
	kwallet-pam \
	openrgb \
	nodejs \
	openssh \
	python \
	python-pip \
	shfmt \
	timeshift \
	tmux \
	ttf-opensans \
	unzip \
	zsh \
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
	visual-studio-code-bin

# Bluetooth
systemctl --user enable bluetooth.service
systemctl --user start bluetooth.service

flatpak install \
	com.brave.Browser \
	com.discordapp.Discord \
	com.slack.Slack \
	com.spotify.Client
