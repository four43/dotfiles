#!/bin/zsh

pathmunge "$HOME/.local/bin"

function join-by { local IFS="$1"; shift; echo "$*"; }

function cheat() {
    if [[ $(echo "python|go" | grep "$1") ]]; then
        local lang="$1"
        shift
        local query="$(join-by "+" $@)"
        curl -s "cheat.sh/${lang}/${query}"
    else
        curl -s "cheat.sh/${1}"
    fi
}

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
