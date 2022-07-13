#!/bin/bash
mkdir -p ~/.fonts
cd ~/.fonts
OUTPUT_ZIP=NotoNerdFont.zip
wget -O "${OUTPUT_ZIP}" https://github.com/ryanoasis/nerd-fonts/releases/download/v2.0.0/Noto.zip
unzip -o "${OUTPUT_ZIP}"
rm "${OUTPUT_ZIP}"
find ~/.fonts | grep "Noto.*Windows" | xargs -n 1 -I % rm -- "%"

