#!/bin/bash
set -e

ubuntu_code_name="$(lsb_release -c | awk '{print $2}')"

echo "deb   https://qgis.org/ubuntu ${ubuntu_code_name} main" | sudo tee /etc/apt/sources.list.d/qgis.list
echo "deb-src   https://qgis.org/ubuntu ${ubuntu_code_name} main" | sudo tee -a /etc/apt/sources.list.d/qgis.list

# Key from
# https://qgis.org/en/site/forusers/alldownloads.html#debian-ubuntu

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key 51F523511C7028C3

sudo apt-get update 
sudo apt-get install qgis qgis-plugin-grass

