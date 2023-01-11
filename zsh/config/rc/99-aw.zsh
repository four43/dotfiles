#!/usr/bin/zsh

export PATH="${PATH}:$HOME/projects/aerisweather/devtools/aws"
alias vpn-up="TMUX_WINDOW_PREV_NAME=\"\$(tmux display-message -p '#W')\"; tmux rename-window '旅AW-VPN'; sudo ~/projects/aerisweather/infra-mgmt/util/vpn/openvpn-connect ~/Documents/AerisWeather/smiller.conf; tmux rename-window \$TMUX_WINDOW_PREV_NAME"
alias project-coverage-open="xdg-open ./.tests-output/test-results/html/index.html"

alias devops-container='docker run --rm -it -v ~/.aws:/root/.aws -v "$PWD:$PWD" -v /var/run/docker.sock:/var/run/docker.sock -w "$PWD" aerisweather/cicd-basics:5 /bin/bash'
alias amp-refresh-asg='docker run --rm -it -v ~/.aws:/root/.aws -v "$PWD:$PWD" -v /var/run/docker.sock:/var/run/docker.sock -w "$PWD" aerisweather/cicd-basics:5 /scripts/ec2-refresh.py refresh "$(aws-ec2-asg-ls amp-)"'

function goes-updated-times() {
    sats=("goes16" "goes17" "goes18")
    for sat in "${sats[@]}"; do
        year="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/" | tail -n 1 | awk '{print $2}' | grep -o -E '[0-9]+')"
        day="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/" | tail -n 1 | awk '{print $2}' | grep -o -E '[0-9]+')"
        hour="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/${day}/" | tail -n 1 | awk '{print $2}' | grep -o -E '[0-9]+')"
        file_list="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/${day}/${hour}/" | tail -n 1)"
        echo "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/${day}/${hour}/" >&2
        if [[ "$?" != "0" ]]; then
            hour=$((hour - 1))
            file_list="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/${day}/${hour}/" | tail -n 1)"
        fi
        echo "$sat updated at $(echo "$file_list" | sed -E 's/.*c([0-9]{4})([0-9]{3})([0-9]{2})([0-9]{2})([0-9]{2}).*/\1 d\2 @ \3:\4:\5Z/')"
    done
}

function is_goes_18() {
    if curl -s 'https://cdn.star.nesdis.noaa.gov/GOES18/ABI/FD/GEOCOLOR/' | grep -q 'GOES18'; then
        echo 'Yup!'
    else
        echo 'Nope.'
    fi
}
