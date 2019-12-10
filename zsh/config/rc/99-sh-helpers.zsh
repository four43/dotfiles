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
    ssh $(echo $ec2_data | awk '{ print $3 }')
}
