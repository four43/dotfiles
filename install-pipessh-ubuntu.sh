#!/usr/bin/env bash

sudo mkdir -p /opt/pipes.sh
USERNAME=$USER
sudo chown $USERNAME:$USERNAME /opt/pipes.sh
cd /opt
git clone https://github.com/pipeseroni/pipes.sh.git

cd pipes.sh
sudo make install
