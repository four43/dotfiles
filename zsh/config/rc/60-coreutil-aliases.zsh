alias ls='ls --color=auto --group-directories-first'
alias ll='ls -l --color=auto --group-directories-first'
alias rm='rm -i'
alias ls-sub-dirs='(for d in */ ; do     echo "$(find $d -maxdepth 1 -type d | wc -l) $d"; done) | sort -rn'

function proxy() {
    echo "Proxying port 1337 to $1"
    ssh -D 1337 -qCN "$@"
}
