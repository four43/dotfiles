#!/bin/bash

# Just use the provided package
sudo apt install -y rxvt-unicode

EXT_DIR="$HOME/.urxvt/ext/"
mkdir -p "${EXT_DIR}"
cd "${EXT_DIR}"
wget https://raw.githubusercontent.com/simmel/urxvt-resize-font/master/resize-font
