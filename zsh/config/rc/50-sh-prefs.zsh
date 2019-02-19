setopt EXTENDED_GLOB

export EDITOR='vi'
export VISUAL="${EDITOR}"

export PAGER="less"
export LESS="-R"

export HISTFILE="${HOME}/.zhistory"
export HISTSIZE=10000
export SAVEHIST=${HISTSIZE}

# Set VI mode for shell
set -o vi
export KEYTIMEOUT=1

# open -> xdg-open
function open () {
  xdg-open "$@">/dev/null 2>&1
}
