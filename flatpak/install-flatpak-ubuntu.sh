#!/bin/bash

sudo apt remove --purge --assume-yes snapd gnome-software-plugin-snap
rm -rf ~/snap/
sudo rm -rf /var/cache/snapd/

sudo apt install flatpak
sudo apt install gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
