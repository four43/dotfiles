alias devops-container='docker run --rm -it -v ~/.aws:/root/.aws -v "$PWD:$PWD" -v /var/run/docker.sock:/var/run/docker.sock -w "$PWD" aerisweather/cicd-basics:4 /bin/bash'
alias amp-refresh-asg='docker run --rm -it -v ~/.aws:/root/.aws -v "$PWD:$PWD" -v /var/run/docker.sock:/var/run/docker.sock -w "$PWD" aerisweather/cicd-basics:4 /scripts/ec2-refresh.py refresh "$(aws-ec2-asg-ls amp-)"'
alias docker-exec="docker ps --format '{{.Names}}' | fzf | xargs -o -n 1 -I % docker exec -it % /bin/bash"
