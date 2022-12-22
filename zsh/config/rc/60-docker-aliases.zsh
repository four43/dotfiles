alias docker-exec="docker ps --format '{{.Names}}' | fzf | xargs -o -n 1 -I % docker exec -it % /bin/bash"
alias docker-compose-shell="docker compose config --services | fzf | xargs -o -I % docker compose run --entrypoint /bin/bash %"
