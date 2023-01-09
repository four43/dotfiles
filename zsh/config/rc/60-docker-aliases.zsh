# BUILDX removes in between containers that makes it really difficult to debug failing builds
export DOCKER_BUILDX=0
export DOCKER_BUILDKIT=0

alias docker-exec="docker ps --format '{{.Names}}' | fzf | xargs -o -n 1 -I % docker exec -it % /bin/bash"
alias docker-run-shell="docker images --format '{{.Repository}}:{{.Tag}}' | fzf | xargs -o -I % docker run --rm -it --entrypoint /bin/bash %"
alias docker-compose-shell="docker compose config --services | fzf | xargs -o -I % docker compose run --entrypoint /bin/bash %"
