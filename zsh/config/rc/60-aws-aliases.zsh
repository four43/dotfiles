#!/usr/bin/zsh
# Thanks jk: https://github.com/jkoelndorfer/dotfiles/blob/master/zsh/config/rc/60-aws-aliases.zsh

function _jq_instance_output_tsv() {
    cat - | jq -r '.Reservations[].Instances[] | [.InstanceId, (.Tags[] | select(.Key == "Name").Value), .PublicDnsName, .State.Name] | @tsv'   
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

function aws-ssm-param-ls() {
    local search_term="$1"
    aws ssm describe-parameters \
        | jq -r '.Parameters[] | (.Name + "\t" + .Description)' \
        | columns \
        | search-output "$search_term" "true"
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

# AerisWeather
function ssh_aeris_api() {
    ssh -i ~/.ssh/work/aeris-api.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@${@}
}

function aeris_api_load_averages() {
    asginstances aeris-api-app-20190528141439425700000003 | awk '{print $2}' | while read ip; do 
        echo -n "$ip: "
        ssh_aeris_api "$ip" -n 'uptime | grep -o "load average:.*" | sed -E '"'"'s/^[^0-9]*([0-9\.]+),\s*([0-9\.]+),\s*([0-9\.]+)$/\1 \2 \3/'"'"'' 2>/dev/null
    done | column -t
}

function aeris_api_5XX() {
    trap 'kill $(jobs -p) 2>/dev/null' SIGINT SIGTERM EXIT
    asginstances aeris-api-app-20190528141439425700000003 | awk '{print $2}' | while read ip; do
        echo "Connecting to $ip">&2
        ssh_aeris_api "$ip" -n 'sudo journalctl -fu aeris-api-nginx | grep -E '"'"' 5[0-9][0-9] "'"'"'' 2>/dev/null &
    done
    echo "Connected to all servers, listening for 5XX repsonse codes..." >&2
    wait    
}

