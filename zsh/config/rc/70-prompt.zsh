setopt PROMPT_SUBST

# Colors (zsh prompt escapes)
RED='%F{red}'
GREEN='%F{green}'
YELLOW='%F{yellow}'
BLUE='%F{blue}'
PURPLE='%F{magenta}'
WHITE='%F{white}'
BOLD='%B'
CLEAR='%f%b'

precmd_functions=(record_lastrc "${precmd_functions[@]}")

VIMODE='insert'
AUTO_SWITCH_AWS='1'
AUTO_SWITCH_GIT='1'

function cwd_indicator() {
	echo -n "${BLUE} %5~${CLEAR}"
}

function host_indicator() {
	[[ -n "$SSH_CONNECTION" ]] && echo -n "${WHITE}󰣀 %m${CLEAR} "
}

function rc_indicator() {
	if [[ "$last_rc" != '0' ]]; then
		echo -n "${RED}${BOLD} ⛌${CLEAR}"
	fi
}

function record_lastrc() {
	last_rc="$?"
}

function user_indicator() {
	if [[ "$EUID" == '0' ]]; then
		echo -n "${RED}>${CLEAR}"
	else
		echo -n "${GREEN}>${CLEAR}"
	fi
}

function vimode_indicator() {
	if [[ "$VIMODE" == 'normal' ]]; then
		echo -n "${YELLOW}⊙${CLEAR} "
	elif [[ "$VIMODE" == 'insert' ]]; then
		: # no indicator for insert mode
	else
		echo -n "${RED}?${CLEAR} "
	fi
}

function zle-keymap-select() {
	if [[ "$KEYMAP" == 'vicmd' ]]; then
		VIMODE='normal'
	elif [[ "$KEYMAP" == 'viins' || "$KEYMAP" == 'main' ]]; then
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
		echo -n " ${GREEN} $(git_branch)${CLEAR}"
		local unpublished=$(git_unpushed_commits_indicator)
		if [[ $(git status --porcelain) != '' ]]; then
			echo -n "${GREEN}ˣ${CLEAR}"
		fi
		if [[ -n "$unpublished" ]]; then
			echo -n " $unpublished"
		fi
	fi
}

# Displays indicator if there are local commits that haven't been pushed to a remote.
function git_unpushed_commits_indicator() {
	if git rev-list @{u}..HEAD >/dev/null 2>&1; then
		local num=$(git rev-list @{u}..HEAD 2>/dev/null | wc -l)
		if [[ "$num" -gt 0 ]]; then
			echo "${YELLOW}$num${CLEAR}"
		fi
	else
		echo "${YELLOW}(new)${CLEAR}"
	fi
}

function git_branch() {
	git rev-parse --abbrev-ref HEAD 2>/dev/null
}

function git_upstream() {
	git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null
}

function python_env_indicator() {
	# Check Pipenv/venv first
	if [[ -n "${VIRTUAL_ENV}" ]]; then
		if [[ "$VIRTUAL_ENV" =~ \.venv ]]; then
			env_name="$(basename "$(realpath "$VIRTUAL_ENV/../")")"
		else
			# Virtual env in virtualenvs folder [project-name]-[random]
			env_name="$(echo "$VIRTUAL_ENV" | sed -E 's/^.*\/([^\/]+)-[^\-]+$/\1/')"
		fi
		echo "${YELLOW}$env_name${CLEAR}"
	elif [[ -n "$CONDA_DEFAULT_ENV" ]] && [[ "$CONDA_DEFAULT_ENV" != "base" ]]; then
		# Else conda (anything but base)
		echo "${YELLOW}${BOLD}${CONDA_DEFAULT_ENV}${CLEAR}"
	fi
}

function aws_auto_switch() {
	# Auto-switch aws env based on project namespace
	if [[ $AUTO_SWITCH_AWS == "1" ]]; then
		local project_dir="$HOME/projects"
		if [[ $PWD =~ ^$project_dir ]]; then
			project_namespace="$(echo "${PWD#$project_dir}" | awk -F'/' '{print $2}')"
			if [[ -z "$AWS_PROFILE" ]] || [[ "$AWS_PROFILE" != "$project_namespace" ]]; then
				set -o pipefail
				if aws-profiles | grep -s "$project_namespace" >/dev/null; then
					export AWS_PROFILE="$project_namespace"
				fi
				set +o pipefail
			fi
		fi
	fi
}

function aws_profile_indicator() {
	[[ -n "$AWS_PROFILE" ]] && [[ "$AWS_PROFILE" != "default" ]] && echo -n "${YELLOW} $AWS_PROFILE${CLEAR}"
}

function in_terraform_dir() {
	[[ -d "$(pwd)/.terraform" ]]
}

function terraform_marker() {
	if in_terraform_dir; then
		echo " ${PURPLE}⛰ ${CLEAR}"
	fi
}

function terraform_ws_indicator() {
	if in_terraform_dir; then
		# Get workspace
		local tf_ws=$(cat "$(pwd)/.terraform/environment" 2>/dev/null)
		if [[ "$?" == 0 ]]; then
			echo "${PURPLE}$tf_ws${CLEAR}"
		fi
	fi
}

function terraform_region_indicator() {
	if in_terraform_dir; then
		# Get region from backend configuration
		local tf_state="$(pwd)/.terraform/terraform.tfstate"
		if [[ -f "$tf_state" ]]; then
			local region=$(grep -o '"region":\s*"[^"]*"' "$tf_state" | head -n1 | cut -d'"' -f4)
			if [[ -n "$region" ]]; then
				echo "${PURPLE}$region/"
			fi
		fi
	fi
}

aws_auto_switch
chpwd_functions+=(aws_auto_switch)

PS1='$(host_indicator)$(cwd_indicator)$(git_indicator) $(aws_profile_indicator)$(python_env_indicator)$(terraform_marker)$(terraform_region_indicator)$(terraform_ws_indicator)$(vimode_indicator)$(rc_indicator)  '
zle -N zle-keymap-select
zle -N accept-line
