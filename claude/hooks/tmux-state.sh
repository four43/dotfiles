#!/usr/bin/env bash
# Claude Code hook: record this session's state on its tmux window as the
# @claude_state window option, which tmux.conf shows in the window list.
#
# Usage: tmux-state.sh working|waiting|clear
#
# No-op outside tmux (e.g. inside a devcontainer, where TMUX_PANE isn't set
# and the host's tmux server isn't reachable). Always exits 0.

[ -n "${TMUX_PANE:-}" ] && command -v tmux >/dev/null 2>&1 || exit 0

case "${1:-}" in
    working|waiting) tmux set -w -t "$TMUX_PANE" @claude_state "$1" ;;
    clear) tmux set -wu -t "$TMUX_PANE" @claude_state ;;
esac >/dev/null 2>&1

tmux refresh-client -S >/dev/null 2>&1
exit 0
