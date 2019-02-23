#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Sets up our "pinned" workspaces and what monitor they should go to.
# I3_WS and I3_WS_MONITORS should be "zipped" together if we need them.
DISPLAYS=($(echo $DISPLAY_ORDER))

# Pointer to self, so we can source this later to maintain our nested array data structure
export WS_CONFIG_FILE="${DOTFILE_DIR}/zsh/config/hostenv/seth-mini-box/$(basename "$0")"

# Array: [key] [name] [output] [command]
WS_TERMINAL=("1" "terminal" "${DISPLAYS[1]}" "i3-sensible-terminal -e zsh -c \"$DOTFILE_DIR/bin/tmux-start\"")
WS_BROWSER=("2" "browser" "${DISPLAYS[0]}" "google-chrome")

export WS_CONFIG=(
    WS_TERMINAL[@]
    WS_BROWSER[@]
)
