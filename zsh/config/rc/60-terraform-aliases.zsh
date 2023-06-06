alias tf="terraform"
function tf-ws {
    tf_env="$1"
    if [[ -z "$tf_env" ]]; then
        terraform workspace list | sed -E 's/^[ \*]+//' | fzf | xargs -n 1 terraform workspace select
    else
        terraform workspace select "$tf_env"
    fi
}

alias cdktf="docker compose run cdktf"
