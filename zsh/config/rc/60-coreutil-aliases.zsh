alias ls='ls --color=auto --group-directories-first'
alias ll='ls -l --color=auto --group-directories-first'
alias rm='rm -i'
alias ls-sub-dirs='(for d in */ ; do     echo "$(find $d -maxdepth 1 -type d | wc -l) $d"; done) | sort -rn'

function btrfs-du() {
    local -A mounts
    while read -r target fsroot; do
        mounts[${fsroot#/}]=$target
    done < <(findmnt -t btrfs -n -o TARGET,FSROOT)

    { printf "%-20s %-15s %10s %10s %15s %8s\n" "SUBVOLUME" "MOUNT" "REFERENCED" "EXCLUSIVE" "MAX_EXCL" "USE%"
    sudo btrfs qgroup show -pcre / \
        | awk '
          function to_bytes(s,    n, u) {
              n = s + 0
              u = s; gsub(/[0-9.]/, "", u)
              if (u == "KiB") return n * 1024
              if (u == "MiB") return n * 1024^2
              if (u == "GiB") return n * 1024^3
              if (u == "TiB") return n * 1024^4
              return n
          }
          NR>2 && /^0\// && !/timeshift/ && !/255\// {
              pct = ($4 == "none") ? "-" : sprintf("%.1f%%", to_bytes($3) / to_bytes($4) * 100)
              printf "%s %s %s %s %s\n", $8, $2, $3, $4, pct
          }' \
        | while read -r subvol rest; do
            mount=${mounts[$subvol]:-"-"}
            printf "%-20s %-15s %s\n" "$subvol" "$mount" "$rest"
          done \
        | sort -k3 -rh; } \
        | column -t
}

function proxy() {
    echo "Proxying port 1337 to $1"
    ssh -D 1337 -qCN "$@"
}
