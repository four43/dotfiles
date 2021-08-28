#!/bin/zsh

pathmunge "$HOME/.local/bin"

function join-by() {
    local IFS="$1"
    shift
    echo "$*"
}

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

function zip-size-analysis() {
    (
        local zip_file="$1"
        local depth="${2:-1}"
        TMP_DIR="$(mktemp -d)"
        trap 'rm -rf "$TMP_DIR"' EXIT
        unzip "$1" -d "$TMP_DIR" >/dev/null 2>&1 || exit $?
        cd "${TMP_DIR}"
        du -h --max-depth="$depth" "./" | head -n -1 | sort -hr
        echo '---'
        du -hs "${TMP_DIR}"
    )
    du -hs "${1}"
}

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
