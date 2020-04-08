#!/bin/bash
set -eo pipefail

latest_url="$(curl -s 'https://www.terraform.io/downloads.html' | grep -oE 'https://releases.hashicorp.com/terraform/0\.12\.[0-9]+/terraform_0\.12\.[0-9]+_linux_amd64\.zip')"

mkdir -p ~/opt
cd ~/opt
wget -O terraform.zip "$latest_url"
unzip terraform.zip

mkdir -p ~/bin
cd ~/bin
if [[ -x "./terraform" ]]; then
    current_version="$(./terraform --version | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')"
    mv ./terraform "./terraform-${current_version}"
fi
mv ~/opt/terraform ~/bin/terraform

current_version="$(./terraform --version | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')"
echo "Installed Terraform ${current_version} successfully." >&2

