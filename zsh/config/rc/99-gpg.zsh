#!/usr/bin/zsh
# Tell gpg-agent which terminal this shell is on, so `pass`/gpg can show a
# pinentry prompt here. Without GPG_TTY, terminal gpg can fail with
# "No pinentry" (gpg-agent has no tty/display to draw on).
export GPG_TTY=$TTY

# Push this shell's TTY (and DISPLAY/WAYLAND_DISPLAY if any) into the running
# gpg-agent. The agent is often long-lived and started by the desktop login,
# so without this an SSH session inherits the stale graphical-session env and
# pinentry-auto picks pinentry-qt → silent hang. Safe no-op if no agent.
command -v gpg-connect-agent >/dev/null && \
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
