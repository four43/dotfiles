# BUILDX removes in between containers that makes it really difficult to debug failing builds

alias docker-compose="docker compose"
alias docker-exec="docker ps --format '{{.Names}}' | fzf | xargs -o -n 1 -I % docker exec -it % /bin/bash"
alias docker-run-shell="docker images --format '{{.Repository}}:{{.Tag}}' | fzf | xargs -o -I % docker run --rm -it --entrypoint /bin/bash %"
alias docker-compose-shell="docker compose config --services | fzf | xargs -o -I % docker compose run --entrypoint /bin/bash %"

function docker-debug () {
    # Docker is annoying to debug failing containers because it keeps auto cleaning things up. Buildkit is useful
    # because it can actually cache multi-stage builds however. Annoying.
    mode="${1}"
    if [[ "$mode" == "on" ]] || [[ "$mode" == "true" ]]; then
        export DOCKER_BUILDX=0
        export DOCKER_BUILDKIT=0
    else
        export DOCKER_BUILDX=1
        export DOCKER_BUILDKIT=1
    fi
}
