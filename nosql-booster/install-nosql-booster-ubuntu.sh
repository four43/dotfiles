#!/bin/bash
set -e

work_dir="$HOME/opt/nosql-booster"
rm -rf "$work_dir" || true
mkdir -p "$work_dir"
cd "$work_dir"

NOSQL_BOOSTER_VERSION=5.2.12
wget 'https://nosqlbooster.com/s3/download/releasesv5/nosqlbooster4mongo-'"${NOSQL_BOOSTER_VERSION}"'.AppImage' -O nosql-booster.AppImage
chmod +x nosql-booster.AppImage
./nosql-booster.AppImage --appimage-extract
cp squashfs-root/nosqlbooster4mongo.png ./nosql-booster.png
rm -rf squashfs-root

nosql_booster_bin="$HOME/opt/nosql-booster/nosql-booster.AppImage"
desktop_file_path="$HOME/.local/share/applications"

mkdir -p "$desktop_file_path"

echo "[Desktop Entry]
Version=1.0
Name=NoSQL Booster
Comment=NoSQL Booster for MongoDB
Exec=$nosql_booster_bin
Icon=$(dirname "$nosql_booster_bin")/nosql-booster.png
Terminal=false
StartupWMClass=nosqlbooster for mongodb
Type=Application
Categories=Network;
" > "${desktop_file_path}/NoSQLBooster.desktop"
