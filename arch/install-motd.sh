#!/usr/bin/env bash
# install-motd.sh — Wire the fastfetch login banner on an Arch host.
#
# Symlinks motd/10-server-info into /etc/profile.d/ so login shells
# (SSH, console, `su -`) render fastfetch on entry. Also installs the
# df-btrfs sudoers rule so the Storage table can query btrfs qgroups
# without a TTY prompt.
#
# Assumes fastfetch is installed (`pacman -S fastfetch`). Enable btrfs
# quotas separately on hosts where you want the subvolume table:
#   sudo btrfs quota enable /
#
# Requires root; re-exec via sudo if invoked without it.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BANNER_SRC="$DOTFILES_ROOT/motd/10-server-info"
BANNER_DEST="/etc/profile.d/motd-fastfetch.sh"
SUDOERS_SRC="$DOTFILES_ROOT/arch/sudoers.d/df-btrfs"
SUDOERS_DEST="/etc/sudoers.d/df-btrfs"

[ -r "$BANNER_SRC" ]  || { echo "missing $BANNER_SRC"  >&2; exit 1; }
[ -r "$SUDOERS_SRC" ] || { echo "missing $SUDOERS_SRC" >&2; exit 1; }

ln -sfn "$BANNER_SRC" "$BANNER_DEST"
echo "Linked $BANNER_DEST -> $BANNER_SRC"

install -m 0440 -o root -g root "$SUDOERS_SRC" "$SUDOERS_DEST"
visudo -c -f "$SUDOERS_DEST" >/dev/null
echo "Installed $SUDOERS_DEST"

command -v fastfetch >/dev/null 2>&1 \
    || echo "warning: fastfetch not installed; banner will be silent until 'pacman -S fastfetch'" >&2
