#!/usr/bin/zsh
# Thanks jk: https://github.com/jkoelndorfer/dotfiles/blob/master/zsh/config/rc/60-aws-aliases.zsh

export AWS_PAGER=""
tab="$(printf '\t')"

function _jq_instance_output_tsv() {
    cat - | jq -r '.Reservations[].Instances[] | [.InstanceId, (.Tags[] | select(.Key == "Name").Value), .PublicDnsName, .PrivateIpAddress, .State.Name] | @tsv'
}

function aws-profile-switch() {
    local search_term="$1"
    force_interactive="1"
    profile_id=$(grep -oP '(?<=\[)([^\]]+)' ~/.aws/credentials | search-output "$search_term")
    export AWS_PROFILE="$profile_id"
}

# Dumps out all of the EC2 instances with the given name.
#
# Usage: aws-ec2-ls [optional search query]
# Outputs: id name hostname state
function aws-ec2-ls() {
    local search_term="$1"
    aws ec2 describe-instances --filter "Name=instance-state-name,Values=running" \
        | _jq_instance_output_tsv \
        | columns \
        | sort -k2 \
        | search-output "$search_term"
}

# Outputs names of AWS EC2 AutoScaling Groups
#
# Usage: aws-ec2-asg-ls [optional search query]
# Outputs: [asg-name]
function aws-ec2-asg-ls() {
    local search_term="$1"
    aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[*].AutoScalingGroupName' --output text \
        | sed -e 's/\t/\n/g' \
        | sort \
        | search-output "$search_term"
}

function aws-ec2-asg-set-min() {
    local asg_name="$1"
    local min_size="$2"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --min-size "$min_size"
}

function aws-ec2-asg-set-desired() {
    local asg_name="$1"
    local desired_size="$2"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --desired-capacity "$desired_size"
}

function aws-ec2-asg-set-max() {
    local asg_name="$1"
    local max_size="$2"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --max-size "$max_size"
}

function aws-ec2-asg-instances-ls() {
    if [[ -n "$1" ]]; then
        local asg_name="$1"
    elif [ ! -t 0 ]; then
        local asg_name="$(cat)"
    fi

    if [[ -z "$asg_name" ]]; then
        pre_force_interactive="$force_interactive"
        force_interactive="1"
        local asg_name="$(aws-ec2-asg-ls)"
        force_interactive="$pre_force_interactive"
    fi

    aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-name "$asg_name" \
        --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
        --output text | sed -e 's/\t/\n/g' \
    | xargs -n 1 -I % aws ec2 describe-instances --instance-ids % \
    | _jq_instance_output_tsv \
    | columns
}

function aws-ec2-unhealthy() {
    if [[ -z "$1" ]]; then
        echo "Must provide an instance id." >&2
        return
    fi
    instance_id="$1"
    instance="$(aws-ec2-ls "$1")"
    if [[ -n "$instance" ]]; then
        echo "This will set the following instance to unhealthy:"
        echo "$instance"
        confirm-cmd aws autoscaling set-instance-health --health-status Unhealthy --instance-id "$instance_id"
    else
        echo "Instance with the id of $instance_id wasn't found" >&2
        return
    fi
}

function _aws-ec2-ami-ls() {
    aws ec2 describe-images --owners self | jq -r '.Images[] | [.Name, .ImageId, .CreationDate] | join("\t")' | sort -k3 -r -t "$tab"
}

function aws-ami-ls() {
    _aws-ec2-ami-ls | columns
}

function aws-ec2-ami-select() {
    {
        echo -e "Name\tImage ID\tCreation Date"
        _aws-ec2-ami-ls
    } | columns | fzf --header-lines 1 | awk '{ print $2 }'
}

function _aws-ec2-lt-ls() {
    aws ec2 describe-launch-templates | jq -r '.LaunchTemplates[] | [.LaunchTemplateName, .LaunchTemplateId, .LatestVersionNumber] | join("\t")'
}

function aws-ec2-lt-ls() {
    {
        echo -e 'Launch Template Name\tLaunch Template ID\tLatest Version'
        _aws-ec2-lt-ls
    } | columns
}

function aws-ec2-lt-select() {
    aws-ec2-lt-ls | fzf --header-lines 1 | awk '{ print $2 }'
}


# Set the AMI-ID on a launch template
function aws-ec2-lt-set-ami () {
    local lt_id=$1
    local ami_id=$2
    aws ec2 create-launch-template-version --launch-template-id "$lt_id" --source-version '$Latest' --launch-template-data '{"ImageId": "'"$ami_id"'"}'
}

function aws-ssm-param-ls() {
    local search_term="$1"
    if [[ -z "$search_term" ]]; then
        results="$(aws ssm describe-parameters)"
    else
        results="$(aws ssm get-parameters-by-path --recursive --path $search_term)"
    fi

    echo "$results" \
        | jq -r '.Parameters[] | (.Name + "\t" + .Description)' \
        | columns \
        | search-output "$search_term" "true"
}

# Creates an SSM Param, making sure one doesn't exists there already
function aws-ssm-param-create() {
    local ssm_path="$1"
    local value="$2"
    local secret="$3"

    local ssm_type="String"
    if [[ -n "$secret" ]]; then
        ssm_type="SecureString"
    fi

    echo "Create '${ssm_path}' set to '${value}' as a '${ssm_type}'?"
    confirm-cmd aws ssm put-parameter \
        --name "${ssm_path}" \
        --value "${value}" \
        --type "${ssm_type}" \
        --no-overwrite
}

# Creates an SSM Param, making sure one doesn't exists there already
function aws-ssm-param-update() {
    local ssm_path="$1"
    local value="$2"
    local secret="$3"

    local ssm_type="String"
    if [[ -n "$secret" ]]; then
        ssm_type="SecureString"
    fi

    echo "Update '${ssm_path}' set to '${value}' as a '${ssm_type}'?"
    confirm-cmd aws ssm put-parameter \
        --name "${ssm_path}" \
        --value "${value}" \
        --type "${ssm_type}" \
        --overwrite
}

# Decrypts an SSM Param. May pass a param as the first argument, stdin, or it will prompt.
#
# Usage: aws-ssm-param-decrypt [optional key]
# Outputs: [decrypted value]
function aws-ssm-param-decrypt() {
    if [[ -n "$1" ]]; then
        local name="$1"
    elif [ ! -t 0 ]; then
        local name="$(cat)"
    fi

    if [[ -z "$name" ]]; then
        pre_force_interactive="$force_interactive"
        force_interactive="1"
        local name="$(aws-ssm-param-ls)"
        force_interactive="$pre_force_interactive"
    fi

    aws ssm get-parameter --name "$name" --with-decryption | jq -r '.Parameter.Value'
}

function aws-s3-cat() {
    if [[ -n "$1" ]]; then
        local s3_path="$1"
    elif [ ! -t 0 ]; then
        local s3_path="$(cat)"
    fi

    tmpfile=$(mktemp /tmp/aws-s3-cat.XXXXXX)
    aws s3 cp "$s3_path" "$tmpfile" 2>&1 >/dev/null || exit 1;
    cat "$tmpfile"
    rm "$tmpfile"
}

function aws-efs-fs-ls {
    aws efs describe-file-systems | jq -r '.FileSystems[] | [.Name,.SizeInBytes.Value,.FileSystemId] | @tsv' | awk '{print $1, $2/1024/1024/1024 "GB", $3}' | column -t | sort
}

# AerisWeather
function goes-updated-times() {
    sats=("goes16" "goes17")
    for sat in "${sats[@]}"; do
        year="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/" | tail -n 1 | awk '{print $2}' | grep -o -E '[0-9]+')"
        day="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/" | tail -n 1 | awk '{print $2}' | grep -o -E '[0-9]+')"
        hour="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/${day}/" | tail -n 1 | awk '{print $2}' | grep -o -E '[0-9]+')"
        file_list="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/${day}/${hour}/" | tail -n 1)"
        echo "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/${day}/${hour}/" >&2
        if [[ "$?" != "0" ]]; then
            hour=$((hour-1))
            file_list="$(aws s3 ls "s3://noaa-${sat}/ABI-L2-CMIPF/${year}/${day}/${hour}/" | tail -n 1)"
        fi
    echo "$sat updated at $(echo "$file_list" | sed -E 's/.*c([0-9]{4})([0-9]{3})([0-9]{2})([0-9]{2})([0-9]{2}).*/\1 d\2 @ \3:\4:\5Z/')"
    done
}

