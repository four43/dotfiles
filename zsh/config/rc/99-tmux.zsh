alias tl='tmux list-sessions';
alias ta='tmux attach-session -d -t $1';

ssh() {
    if [[ -n "$TMUX" ]]; then
        tmux rename-window "力$(echo $* | cut -d . -f 1)"
        command ssh "$@"
        tmux set-window-option automatic-rename "on" 1>/dev/null
    else
        command ssh "$@"
    fi
}

precmd() {
    if [[ -n "$TMUX" ]]; then
        tmux rename-window "zsh|$(basename $(pwd))"
    fi
}
