alias devops-container="docker run --rm -it -v ~/.aws:/root/.aws -v $(pwd):/app -v /var/run/docker.sock:/var/run/docker.sock -w /app aerisweather/cicd-basics:2.12.0 /bin/bash"
alias docker-exec="docker ps --format '{{.Names}}' | fzf | xargs -o -n 1 -I % docker exec -it % /bin/bash"
