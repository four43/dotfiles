#!/bin/zsh

alias wlan-ip="curl -s checkip.amazonaws.com"

function nmap-find-local {
    nmap -sL 192.168.1.0/24 | grep "$1"
}
