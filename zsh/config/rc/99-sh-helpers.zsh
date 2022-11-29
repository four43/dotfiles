#!/usr/bin/zsh

function ls-details() {
    find -mindepth 1 $1 | sort | while read f; do { du -h "$f"; md5sum "$f"; } | sed 'N;s/\n/ /'; done | gawk '{print $1, $3, $4}' OFS='\t'
}

function password() {
    local length="${1:-16}"
    base64 /dev/urandom | head -c "${length}" | awk '{print $1}'
}

function ssh-ec2() {
    force_interactive="1"
    local ec2_data="$(aws-ec2-ls $1)"
    if [[ $? == 0 ]]; then
        echo "SSHing to $(echo $ec2_data | awk '{ print $2,"(",$4," ",$3,")" }')..." >&2
        ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" $(echo $ec2_data | awk '{ print $4 }')
    fi
}

function wget-mirror() {
    # Thanks to: https://stackoverflow.com/a/46820751/387851
    url="$1"
    NSLASH="$(echo "${url}" | perl -pe 's|.*://[^/]+(.*?)/?$|\1|' | grep -o / | wc -l)"
    NCUT=$((NSLASH > 0 ? NSLASH-1 : 0))
    wget \
        --recursive \
        --no-host-directories \
        --no-parent \
        --cut-dirs="$NCUT" \
        --execute robots=off \
        --user-agent='Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0' \
        --reject="index.html*" \
         "${url}"
}
