#!/bin/bash
mkdir -p ~/.fonts
cd ~/.fonts
OUTPUT_ZIP=DejaVuSansMonoNerdFont.zip
wget -O "${OUTPUT_ZIP}" https://github.com/ryanoasis/nerd-fonts/releases/download/v2.0.0/DejaVuSansMono.zip
unzip -o "${OUTPUT_ZIP}"
rm "${OUTPUT_ZIP}"
find ~/.fonts | grep "DejaVu Sans Mono.*Windows" | xargs -n 1 -I % rm -- "%"

