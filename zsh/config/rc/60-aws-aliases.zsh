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
        --output text | sed -e 's/\t/\n/g' \
    | xargs -n 1 -I % aws ec2 describe-instances --instance-ids % \
    | jq -r '.Reservations[0].Instances[0] | [.InstanceId,.PublicDnsName, (.Tags[] | select(.Key == "Name").Value), .State.Name] | @tsv'
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


# AerisWeather
function ssh_aeris_api() {
    ssh -i ~/.ssh/work/aeris-api.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@${@}
}

function aeris_api_load_averages() {
    asginstances aeris-api-app-20190528141439425700000003 | while read i; do 
        ip=$(ec2_instance_public_ip "$i")
        echo -n "$ip: "
        ssh_aeris_api "$ip" -n 'uptime | grep -o "load average:.*" | sed -E '"'"'s/^[^0-9]*([0-9\.]+),\s*([0-9\.]+),\s*([0-9\.]+)$/\1 \2 \3/'"'"'' 2>/dev/null
    done | column -t
}

function aeris_api_5XX() {
    trap 'kill $(jobs -p) 2>/dev/null' SIGINT SIGTERM EXIT
    asginstances aeris-api-app-20190528141439425700000003 | while read i; do
        ip=$(ec2_instance_public_ip "$i")
        echo "Connecting to $ip">&2
        ssh_aeris_api "$ip" -n 'sudo journalctl -fu aeris-api-nginx | grep -E '"'"' 5[0-9][0-9] "'"'"'' 2>/dev/null &
    done
    echo "Connected to all servers, listening for 5XX repsonse codes..." >&2
    wait    
}

 function test_func () { while true; do echo "hello"; sleep 1; done }

function test_all() {
    trap 'kill $(jobs -p) 2>/dev/null' SIGINT SIGTERM EXIT

    test_func &
    test_func &

    wait

}
