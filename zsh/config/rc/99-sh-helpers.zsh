#!/usr/bin/zsh

function ls-details() {
    find -mindepth 1 $1 | sort | while read f; do { du -h "$f"; md5sum "$f"; } | sed 'N;s/\n/ /'; done | gawk '{print $1, $3, $4}' OFS='\t'
}

# Creates a password of the specified length (uses base64 characters without problematic ones like / or +)
# For machine use, will use visually similar characters.
function password() {
    local length="${1:-16}"
    base64 /dev/urandom | sed 's/[+\/=\n]//g' | tr -d '\n' | head -c "${length}" | awk '{print $1}'
}

function ec2-connect() {
    echo "Connecting via SSM..." >&2

    local tags
    case "$env" in
        dev)
            tags="Name=tag:xwx:engineering-environment,Values=dev"
            ;;
        staging)
            tags="Name=tag:xwx:engineering-environment,Values=staging"
            ;;
        prod)
            tags="Name=tag:xwx:engineering-environment,Values=prod"
            ;;
        *)
            echo "No environment filter being used!" >&2
            tags="Name=tag:xwx:engineering-environment,Values=*"
            sleep 1
            ;;
    esac

    selected=$(
        aws ec2 describe-instances \
            --filters "Name=instance-state-name,Values=running" "$tags" \
            | jq -r \
                '.Reservations[].Instances[]
                | [(if has("Tags") then .Tags[]
                | select(.Key == "Name").Value else "None" end), .InstanceId]
                | @tsv' \
            | fzf
    )
    if [ -z "$selected" ]; then
        echo "No instance selected!" >&2
        return 1
    fi

    echo "Connecting to server: ${selected}..." >&2

    if [ -n "$selected" ]; then

        instance_id=$(echo "$selected" | cut -f2)
        aws ssm start-session \
        --document-name linux-zsh-ssh \
        --target "$instance_id"
    fi
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

function find-desktop() {
    DATA_DIRS="$XDG_DATA_DIRS:$HOME/.local/share"
    for p in ${DATA_DIRS//:/ }; do
        find $p/applications -name '*.desktop' 2>/dev/null | grep -i -e "$1"
    done
}

function which-desktop() {
    find-desktop "$1" | head -n 1 | xargs cat | grep '^Exec' | cut -d '=' -f 2
}
