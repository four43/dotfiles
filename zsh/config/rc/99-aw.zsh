#!/usr/bin/zsh

export PATH="${PATH}:$HOME/projects/aerisweather/devtools/aws"
alias vpn-up="TMUX_WINDOW_PREV_NAME=\"\$(tmux display-message -p '#W')\"; tmux rename-window '旅AW-VPN'; sudo ~/projects/aerisweather/infra-mgmt/util/vpn/openvpn-connect ~/Documents/AerisWeather/smiller.conf; tmux rename-window \$TMUX_WINDOW_PREV_NAME"
