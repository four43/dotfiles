#!/bin/bash
set -e

work_dir="$HOME/opt/postman"
rm -rf "$work_dir" || true
mkdir -p "$work_dir"
cd "$work_dir"

wget https://dl.pstmn.io/download/latest/linux64 -O postman.tar.gz
tar -xzf ./postman.tar.gz

postman_bin="$HOME/opt/postman/Postman/app/Postman"
desktop_file_path="$HOME/.local/share/applications"

mkdir -p "$desktop_file_path"

echo "[Desktop Entry]
Version=1.0
Name=Postman
Comment=Postman Native App
Exec=$postman_bin — %u
Icon=$(dirname "$postman_bin")/resources/app/assets/icon.png
Terminal=false
StartupWMClass=postman
Type=Application
Categories=Network;
" > "${desktop_file_path}/Postman.desktop"
