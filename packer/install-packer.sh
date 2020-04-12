#!/bin/bash
set -xeo pipefail

latest_url="$(curl -s 'https://packer.io/downloads.html' | grep -oE 'https://releases.hashicorp.com/packer/1\.[0-9]+\.[0-9]+/packer_1\.[0-9]+\.[0-9]+_linux_amd64\.zip')"

mkdir -p ~/opt
cd ~/opt
wget -O packer.zip "$latest_url"
unzip packer.zip

mkdir -p ~/bin
cd ~/bin
if [[ -x "./packer" ]]; then
    current_version="$(./packer --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    mv ./packer "./packer-v${current_version}"
fi
mv ~/opt/packer ~/bin/packer

current_version="$(./packer --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
echo "Installed Packer ${current_version} successfully." >&2

