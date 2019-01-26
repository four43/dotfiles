#!/bin/bash
mkdir -p ~/.fonts
cd ~/.fonts
wget -O DejaVuSansMonoNerdFont.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v2.0.0/DejaVuSansMono.zip
unzip -o DejaVuSansMonoNerdFont.zip
find ~/.fonts | grep "DejaVu Sans Mono.*Windows" | xargs -n 1 -I % rm -- "%"

