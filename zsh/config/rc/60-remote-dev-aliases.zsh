# remote-dev — helpers for the EC2 dev box (`Host remote-dev` in
# ~/.ssh/config-remote-dev, written by `remote-dev ssh-config --write`).

# Paste the local Wayland clipboard onto remote-dev as a file.
#   rd-paste            -> ~/paste/clip-<timestamp>.<ext> on the remote
#   rd-paste <path>     -> <path> on the remote (relative to remote $HOME)
# Images win over text when both are offered (e.g. a screenshot tool), so a
# screenshot lands as a .png you can hand to Claude running on the box. The
# remote path is printed and put back on the clipboard, ready to paste into the
# remote shell. Override the host with RD_HOST.
rd-paste() {
    local host="${RD_HOST:-remote-dev}"
    local -a types
    types=("${(@f)$(wl-paste --list-types 2>/dev/null)}")
    if [[ -z "${types[1]}" ]]; then
        print -u2 "rd-paste: clipboard is empty"
        return 1
    fi

    local mime ext remote_path
    case "${(M)types:#image/*}" in
        *image/png*)  mime=image/png  ext=png ;;
        *image/jpeg*) mime=image/jpeg ext=jpg ;;
        *image/*)     mime=image/png  ext=png ;;  # let wl-paste convert
        *)            mime=text/plain ext=txt ;;
    esac

    local dest="${1:-paste/clip-$(date +%Y%m%d-%H%M%S).$ext}"

    # ${(q)dest} so spaces/globs in the path survive the remote shell.
    wl-paste --no-newline --type "$mime" \
        | ssh "$host" "mkdir -p \"\$(dirname ${(q)dest})\" && cat > ${(q)dest} && realpath ${(q)dest}" \
        | read -r remote_path || return

    print "$host:$remote_path"
    print -rn -- "$remote_path" | wl-copy
}
