#!/usr/bin/zsh

# Thanks jk: https://github.com/jkoelndorfer/dotfiles/blob/master/zsh/config/rc/60-aws-aliases.zsh

# Dumps out all of the EC2 instances with the given name.
function ec2_instances_named() {
    local name="$1"
    aws ec2 describe-instances --filters "Name=tag:Name,Values=$name"
}

function ec2_instance_names() {
    aws ec2 describe-instances --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value' | jq -r '.[][0][0]' | sort -u
}

function ec2_instance_public_ip() {
    local instance_id=$1

    aws ec2 describe-instances \
        --instance-id "$instance_id" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text
}

function lsasg() {
    aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[*].AutoScalingGroupName' --output text |
        sed -e 's/\t/\n/g' | sort
}

function asgmin() {
    local asg_name=$1
    local min_size=$2

    aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --min-size "$min_size"
}

function asgdesired() {
    local asg_name=$1
    local desired_capacity=$2

    aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --desired-capacity "$desired_capacity"
}

function asgmax() {
    local asg_name=$1
    local max_size=$2

    aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --max-size "$max_size"
}

function asginstances() {
    local asg_name=$1

    aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-name "$asg_name" \
        --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
        --output text | sed -e 's/\t/\n/g'
}


function lsssmp() {
    aws ssm describe-parameters --query 'Parameters[].Name' --output text | sed -e 's/\t/\n/g' | sort
}

function ssmp() {
    if [[ -n "$1" ]]; then
        local name=$1
    else
        local name=$(select_ssm_param)
    fi
    aws ssm get-parameter --name "$name" --with-decryption | jq -r '.Parameter.Value'
}

function select_ssm_param() {
    local tab=$(echo -e '\t')
    aws ssm describe-parameters |
        jq -r '.Parameters[] | (.Name + "\t" + .Description)' |
        column -t -s "$tab" | fzf | awk '{ print $1 }'
}
