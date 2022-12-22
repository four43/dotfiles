#!/usr/bin/zsh

export PATH="${PATH}:$HOME/projects/aerisweather/devtools/aws"
alias vpn-up="TMUX_WINDOW_PREV_NAME=\"\$(tmux display-message -p '#W')\"; tmux rename-window '旅AW-VPN'; sudo ~/projects/aerisweather/infra-mgmt/util/vpn/openvpn-connect ~/Documents/AerisWeather/smiller.conf; tmux rename-window \$TMUX_WINDOW_PREV_NAME"
alias project-coverage-open="xdg-open ./.tests-output/test-results/html/index.html"

alias devops-container='docker run --rm -it -v ~/.aws:/root/.aws -v "$PWD:$PWD" -v /var/run/docker.sock:/var/run/docker.sock -w "$PWD" aerisweather/cicd-basics:5 /bin/bash'
alias amp-refresh-asg='docker run --rm -it -v ~/.aws:/root/.aws -v "$PWD:$PWD" -v /var/run/docker.sock:/var/run/docker.sock -w "$PWD" aerisweather/cicd-basics:5 /scripts/ec2-refresh.py refresh "$(aws-ec2-asg-ls amp-)"'

function is_goes_18() {
    if curl -s 'https://cdn.star.nesdis.noaa.gov/GOES18/ABI/FD/GEOCOLOR/' | grep -q 'GOES18'; then
        echo 'Yup!'
    else
        echo 'Nope.'
    fi
}
