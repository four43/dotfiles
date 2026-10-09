#!/usr/bin/env bash
# Claude Code hook: hold or release this session's remote-dev idle lease, so a
# remote-dev EC2 host doesn't stop itself while Claude is working.
#
# Usage: remote-dev-lease.sh hold|release   (hook JSON is passed through on stdin)
#
# No-op unless this is a remote-dev host: the remote-dev CLI must be on PATH and
# its lease directory (created by `remote-dev` host install, on tmpfs under
# /run) must exist. Elsewhere it exits 0 without reading stdin.

[ -d /run/remote-dev/leases ] && command -v remote-dev >/dev/null 2>&1 || exit 0

case "${1:-}" in
    hold|release) exec remote-dev hooks "$1" ;;
esac
exit 0
