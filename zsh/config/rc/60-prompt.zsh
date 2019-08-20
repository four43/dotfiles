setopt PROMPT_SUBST

precmd_functions=(record_lastrc "${precmd_functions[@]}")

VIMODE='insert'

function cwd_indicator() {
    echo -n '%F{blue} %5~%f'
}

function host_indicator() {
    [[ -n "$SSH_CONNECTION" ]] && echo -n '%F{white}力 %m%f '
}

function rc_indicator() {
    if [[ "$last_rc" != '0' ]]; then
        color='red'
        echo -n "%F{red}✖️%f"
    fi
}

function record_lastrc() {
    last_rc="$?"
}

function user_indicator() {
    local color='green'
    if [[ "$EUID" == '0' ]]; then
        color='red'
    fi
    echo -n "%F{$color}>%f"
}

function vimode_indicator() {
    local color=''
    local char=''
    if [[ "$VIMODE" == 'normal' ]]; then
        color='yellow'
        char=''
    elif [[ "$VIMODE" == 'insert' ]]; then
        color='green'
        char=''
    else
        color='red'
        char='?'
    fi
    echo -n "%F{$color}$char%f "
}

function zle-keymap-select() {
    if [[ "$KEYMAP" == 'vicmd' ]]; then
        VIMODE='normal'
    elif [[ "$KEYMAP" == 'viins'  || "$KEYMAP" == 'main' ]]; then
        VIMODE='insert'
    else
        VIMODE='?'
    fi
    zle reset-prompt
}

function accept-line() {
    VIMODE='insert'
    builtin zle .accept-line
}

function in_git_repo() {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Displays an indicator if the current git repo is dirty (any untracked files, any staged files that aren't committed yet)
function git_indicator() {
    if in_git_repo; then
        echo -n " %F{green} $(git_branch)%f"
        local unpublished=$(git_unpushed_commits_indicator)
        if [[ $(git status --porcelain) != '' ]]; then
            echo -n '%F{green}ˣ%f'
        fi
        if [[ -n "$unpublished" ]]; then
            echo -n " $unpublished"
        fi
    fi
}

# Displays indicator if there are local commits that haven't been pushed to a remote.
function git_unpushed_commits_indicator() {
    local num=$(git rev-list @{u}..HEAD 2>/dev/null | wc -l)
    if [[ "$num" -gt 0 ]]; then
        echo "%F{yellow}$num%f"
    fi
}

function git_branch() {
    git rev-parse --abbrev-ref HEAD
}

function git_upstream() {
    git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null
}

function python_env() {
    # Check Pipenv/venv first

    # Else conda (anything but base)
    if [[ -x conda ]]; then
        conda_env="$(conda info --envs | grep '*' | awk '{print $1}')"
        if [[ "${conda_env}" != "base" ]]; then
            echo "${conda_env}"
        fi
    fi
}

function in_terraform_dir() {
    [[ -d "$(pwd)/.terraform" ]]
}

function terraform_ws() {
    if in_terraform_dir; then
        # Get workspace
        local tf_ws=$(cat "$(pwd)/.terraform/environment")
        if [[ "$?" == 0 ]]; then
            echo "%F{purple}$tf_ws%f"
        fi
    fi
}

PS1='$(host_indicator)$(cwd_indicator)$(git_indicator) $(python_env)$(terraform_ws)$(vimode_indicator)$(rc_indicator)\$ '
zle -N zle-keymap-select
zle -N accept-line
