#!/bin/bash

sudo apt-get update
sudo apt-get purge rofi
sudo apt-get install bison flex librsvg2
sudo mkdir -p /opt/rofi
sudo chown $USER:$USER /opt/rofi

git clone git@github.com:davatorium/rofi.git /opt/rofi
cd /opt/rofi
git checkout 1.5.4
git submodule update --init
autoreconf -i

mkdir -p build
cd build
../configure --disable-check
make
sudo make install
