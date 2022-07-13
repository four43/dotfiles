#!/bin/zsh

function nmap-find-local {
    nmap -sL 192.168.1.0/24 | grep "$1"
}
