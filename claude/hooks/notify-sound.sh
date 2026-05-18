#!/usr/bin/env bash
# Claude Code Stop/Notification hook: play a sound or ring a bell.
#
# Strategy:
#   1. If PulseAudio is reachable, play the freedesktop "complete" chime.
#      Works on the host (alacritty + tmux, plain terminal, etc.).
#   2. Otherwise (e.g. inside a devcontainer with no audio socket), walk
#      up the parent process tree, find a tty, and emit a terminal bell
#      so VSCode's integrated terminal can sound the bell on the host.
#
# Always exits 0 — never fail the hook just because we couldn't beep.

set -u

if [ -e "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse/native" ] \
   && command -v paplay >/dev/null 2>&1; then
    paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null && exit 0
fi

p=$PPID
while [ -n "${p:-}" ] && [ "$p" -gt 1 ] 2>/dev/null; do
    t=$(ps -o tty= -p "$p" 2>/dev/null | tr -d ' \n')
    case "$t" in
        pts/*|tty*)
            printf '\a' > "/dev/$t" 2>/dev/null && exit 0
            ;;
    esac
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' \n')
done

exit 0
