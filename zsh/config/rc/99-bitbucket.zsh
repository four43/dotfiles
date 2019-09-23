#!/usr/bin/env zsh

function bitbucket() {
    local origin_url=$(git remote get-url origin)
    if [[ -z "$origin_url" ]]; then
        echo "Not in a git repository, can't open bitbucket from here" >&2
        exit 1
    fi

    origin_web_url=$(echo "$origin_url" | cut -d '@' -f2 | sed 's/:/\//g' | sed 's/\.git$//')   


    xdg-open "https://$origin_web_url" 1>&2 2>/dev/null
}

function github() {
    bitbucket
}

