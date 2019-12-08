#!/bin/zsh
dconf load /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ < "${DOTFILE_DIR}/gnome/keybindings-custom.dconf"

