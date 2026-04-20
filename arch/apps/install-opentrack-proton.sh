#!/bin/bash

sudo pacman -S python p7zip wget

mkdir -p ~/.local/bin
wget https://raw.githubusercontent.com/VolatileMark/opentrack-launcher/master/opentrack-launcher -O ~/.local/bin/opentrack-launcher
chmod +x ~/.local/bin/opentrack-launcher