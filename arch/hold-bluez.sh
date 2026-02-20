#!/bin/bash

# Issue with the latest bluez on 2026-02-20

sudo pacman -U \
  https://archive.archlinux.org/packages/b/bluez/bluez-5.85-1-x86_64.pkg.tar.zst \
  https://archive.archlinux.org/packages/b/bluez-utils/bluez-utils-5.85-1-x86_64.pkg.tar.zst \
  https://archive.archlinux.org/packages/b/bluez-libs/bluez-libs-5.85-1-x86_64.pkg.tar.zst

# Add to IgnorePkg in pacman.conf so they aren't upgraded
sudo sed -i '/^#\?IgnorePkg/c\IgnorePkg = bluez bluez-utils bluez-libs' /etc/pacman.conf

echo "To undo, edit /etc/pacman.conf and remove or comment out the IgnorePkg line."

