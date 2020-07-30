#!/bin/bash

INSTALL_DIR="~/opt"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
wget -O 'bat.deb' 'https://github.com/sharkdp/bat/releases/download/v0.15.4/bat-musl_0.15.4_amd64.deb'
sudo dpkg -i 'bat.deb'
