alias devops-container='docker run --rm -it -v ~/.aws:/root/.aws -v "$PWD:$PWD" -v /var/run/docker.sock:/var/run/docker.sock -w "$PWD" aerisweather/cicd-basics:3 /bin/bash'
alias docker-exec="docker ps --format '{{.Names}}' | fzf | xargs -o -n 1 -I % docker exec -it % /bin/bash"
