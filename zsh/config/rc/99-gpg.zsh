#!/usr/bin/zsh
# Tell gpg-agent which terminal this shell is on, so `pass`/gpg can show a
# pinentry prompt here. Without GPG_TTY, terminal gpg can fail with
# "No pinentry" (gpg-agent has no tty/display to draw on).
export GPG_TTY=$TTY
