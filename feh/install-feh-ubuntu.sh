#!/bin/bash

INSTALL_DIR="/opt/feh"
sudo mkdir -p "${INSTALL_DIR}"
sudo chown $USER:$USER "${INSTALL_DIR}"
cd "${INSTALL_DIR}"
ZIP_NAME="feh.tar.bz2"
wget -O "${ZIP_NAME}" https://feh.finalrewind.org/feh-3.1.1.tar.bz2
tar -xvjf "${ZIP_NAME}"

sudo apt install -y \
   libcurl4-openssl-dev \
   libx11-dev \
   libxt-dev \
   libimlib2-dev \
   libxinerama-dev \
   libjpeg-progs
   
cd feh-3.1.1
make
sudo make install
