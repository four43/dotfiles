#!/usr/bin/env bash
set -e 
sudo add-apt-repository universe
sudo apt update && sudo apt install -y \
	build-essential \
	cmake \
	cmake-data \
	libcairo2-dev \
	libxcb1-dev \
	libxcb-ewmh-dev \
	libxcb-icccm4-dev \
	libxcb-image0-dev \
	libxcb-composite0-dev \
	libxcb-randr0-dev \
	libxcb-util0-dev \
	libxcb-xkb-dev \
	pkg-config \
	python-xcbgen \
	xcb-proto \
	libxcb-xrm-dev \
	libasound2-dev \
	libmpdclient-dev \
	libiw-dev \
	libcurl4-openssl-dev \
	libpulse-dev

sudo mkdir -p /opt/polybar
USERNAME=$USER
sudo chown $USERNAME:$USERNAME /opt/polybar
cd /opt/polybar
git clone https://github.com/jaagr/polybar.git
cd polybar
./build.sh -A --all-features
