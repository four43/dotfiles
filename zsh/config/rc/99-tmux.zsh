alias tl='tmux list-sessions';
alias ta='tmux attach-session -d -t $1';

# Title windows with nice titles so we can keep track of waht is going on in them
# - Remote session indicators should take priority "力[server]"
# - Separate next thing via "|"

ssh() {
    if [[ -n "$TMUX" ]]; then
        tmux rename-window "力$(echo "$@" | awk '{print $NF}' | cut -d . -f 1)"
        command ssh "$@"
        tmux set-window-option automatic-rename "on" 1>/dev/null
    else
        command ssh "$@"
    fi
}

precmd() {
    if [[ -n "$TMUX" ]]; then
        current_window_name="$(tmux display-message -p '#W')"
        echo $current_window_name > /tmp/window-name.txt
        if [[ "$current_window_name" =~ ^(|zsh) ]]; then
            tmux rename-window "$(basename "$(pwd)")"
        fi
    fi
}

python() {
    if [[ -n "$TMUX" ]]; then
        tmux rename-window "$(basename "$(pwd)")"
        command python "$@"
        # tmux set-window-option automatic-rename "on" 1>/dev/null
    else
        command python "$@"
    fi
}
