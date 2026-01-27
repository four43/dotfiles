#!/bin/bash
set -euo pipefail

# In order to clone the repo you will probably need git and openssh

sudo pacman -S \
	alacritty \
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
	kwallet \
	kwallet-pam \
	openssh \
	python \
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

yay -S visual-studio-code-bin
