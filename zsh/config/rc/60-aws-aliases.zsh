#!/usr/bin/zsh

export AWS_PAGER=""
tab="$(printf '\t')"

function _jq_instance_output_tsv() {
    cat - | jq -r '.Reservations[].Instances[] | [.InstanceId, (.Tags[] | select(.Key == "Name").Value), .PublicDnsName, .PrivateIpAddress, .State.Name] | @tsv'
}

function aws-profile-switch() {
    local search_term="$1"
    if [[ -t 1 ]]; then
        force_interactive="1"
    fi
    profile_id="$(grep -oP '(?<=\[)([^\]]+)' ~/.aws/credentials | search-output "$search_term")"
    if [[ $? == 0 ]]; then
        export AWS_PROFILE="$profile_id"
    else
        echo "Failed selecting profile by ${search_term}" >&2
        # return 1
    fi
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
    if ! [[ -t 1 ]]; then
        force_interactive="1"
    fi
    local search_term="$1"
    aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[*].AutoScalingGroupName' --output text \
        | sed -e 's/\t/\n/g' \
        | sort \
        | search-output "$search_term"
}

function aws-ec2-asg-set-min() {
    if ! [[ -t 1 ]]; then
        force_interactive="1"
    fi
    local asg_name="$(aws-ec2-asg-ls "$1")"
    local min_size="$2"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --min-size "$min_size"
    echo "$asg_name min size set to $min_size" >&2
}

function aws-ec2-asg-set-desired() {
    if ! [[ -t 1 ]]; then
        force_interactive="1"
    fi
    local asg_name="$(aws-ec2-asg-ls "$1")"
    local desired_size="$2"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --desired-capacity "$desired_size"
    echo "$asg_name desired size set to $desired_size" >&2
}

function aws-ec2-asg-set-max() {
    if ! [[ -t 1 ]]; then
        force_interactive="1"
    fi
    local asg_name="$(aws-ec2-asg-ls "$1")"
    local max_size="$2"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$asg_name" --max-size "$max_size"
    echo "$asg_name max size set to $desired_size" >&2
}

function aws-ec2-asg-instances-ls() {
    if ! [[ -t 1 ]]; then
        force_interactive="1"
    fi
    local asg_name="$(aws-ec2-asg-ls "$1")"
    aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-name "$asg_name" \
        --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
        --output text | sed -e 's/\t/\n/g' \
        | xargs -n 1 -I % aws ec2 describe-instances --instance-ids % \
        | _jq_instance_output_tsv \
        | columns
}

function aws-ec2-asg-stuck() {
    aws autoscaling describe-auto-scaling-groups \
    | jq -r '.AutoScalingGroups[] | {AutoScalingGroupName,SuspendedProcesses} | select(.SuspendedProcesses[].ProcessName == "Launch") | .AutoScalingGroupName'
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

function aws-ec2-lt-ls() {
    local search_term="$1"

    {
        echo -e 'Launch Template Name\tLaunch Template ID\tLatest Version'
        aws ec2 describe-launch-templates  \
            |jq -r '.LaunchTemplates[] | [.LaunchTemplateName, .LaunchTemplateId, .LatestVersionNumber] | join("\t")'
    } | columns \
            | fzf --header-lines 1
}

# Set the AMI-ID on a launch template
function aws-ec2-lt-set-ami() {
    local lt_id=$1
    local ami_id=$2
    aws ec2 create-launch-template-version --launch-template-id "$lt_id" --source-version '$Latest' --launch-template-data '{"ImageId": "'"$ami_id"'"}'
}

function aws-ssm-param-ls() {
    local search_term="$1"
    if [[ -z "$search_term" ]]; then
        results="$(aws ssm describe-parameters --page-size 10)"
    else
        results="$(aws ssm get-parameters-by-path --page-size 10 --recursive --path $search_term)"
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

function aws-s3-prefix-sizes() {
    local bucket="$1"
    for product in $(aws s3 ls "$bucket" | grep \/ | awk '{print $2}'); do
        echo ${product};
        aws s3 ls "$bucket/${product}" --recursive --summarize --human | grep Total;
        echo "";
    done
}

function aws-s3-cat() {
    aws s3 cp --quiet "$1" /dev/stdout
}

function aws-s3-edit() {
    set -x
    TMP_FILE="$(mktemp /tmp/edit-pipe.XXXXXXXX)"
    trap "rm \"$TMP_FILE\"" EXIT
    aws s3 cp "$1" "${TMP_FILE}"
    if [[ $? != 0 ]]; then
        echo "No $1 file found on S3" >&2
        rm "${TMP_FILE}"
    fi

    $EDITOR "${TMP_FILE}" </dev/tty >/dev/tty
    if [[ $? == 0 ]]; then
        aws s3 cp "${TMP_FILE}" "$1"
    fi
}

function aws-s3-cp-latest() {
    local bucket_and_prefix="$1"
    if [[ -z $bucket_and_prefix ]]; then
        echo "Needs s3 bucket/prefix as first arg. s3://bucket/prefix/" >&2
    fi
    local destination="$2"
    if [[ -z $bucket_and_prefix ]]; then
        echo "Needs destination as second arg." >&2
    fi
    local count="${3:-5}"
    aws s3 ls "${bucket_and_prefix}" | tail -n "${count}" | awk '{ print $4 }' | xargs -n 1 -I % aws s3 cp "${bucket_and_prefix}%" "${destination}"
}

function aws-efs-fs-ls() {
    aws efs describe-file-systems | jq -r '.FileSystems[] | [.Name,.SizeInBytes.Value,.FileSystemId] | @tsv' | awk '{print $1, $2/1024/1024/1024 "GB", $3}' | column -t | sort
}

function aws-cloud-front-lambda-at-edge-logs-ls() {
    local function_name="$1"
    if [[ -z "$function_name" ]]; then
        echo "Supply function name as first argument" >&2
        return 1
    fi
    for region in $(aws --output text ec2 describe-regions | awk '{print $4}'); do
        for loggroup in $(aws --output text logs describe-log-groups --log-group-name "/aws/lambda/us-east-1.$function_name" --region $region --query 'logGroups[].logGroupName'); do
            echo $region $loggroup
        done
    done
}

function aws-lambda-ls() {
    if ! [[ -t 1 ]]; then
        force_interactive="1"
    fi
    local search_term="$1"
    aws lambda list-functions --query 'Functions[*].FunctionName' --output text \
        | sed -e 's/\t/\n/g' \
        | sort \
        | search-output "$search_term"
}

function aws-lambda-logs() {
    function_name="$1"
    if [[ -z "$function_name" ]]; then
        function_name="$(aws-lambda-ls)"
    fi
    aws logs tail --since 1h --follow "/aws/lambda/${function_name}"
}

function aws-ec2-logs() {
    log_name="$1"
    if [[ -z "$function_name" ]]; then
        log_name="$(aws logs describe-log-groups --log-group-name-prefix "/aeris/ec2" \
                | jq -r '.logGroups[].logGroupName' \
                | fzf)"
    fi
    aws logs tail \
        "${log_name}" \
        --since 1h \
        --format short \
        --follow \
        | sed -E 's/^([0-9\:T-]+) \{/{ "__logTime__": "\1",/' \
        | jq -r '"\(.__logTime__) \u001b[93m[\(.syslog.ident)]\u001b[0m \(.message)"'
}
