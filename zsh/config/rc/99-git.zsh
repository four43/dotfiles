DIR="$(dirname "$(readlink -f "$0")")"

# Add git helpers to path
export PATH="$PATH:$DOTFILE_DIR/bin/git"

export GIT_SSH_COMMAND="$DOTFILE_DIR/git/git-ssh-key-rotation.sh"

# Install autocomplete for git-* programs
zstyle ':completion:*:*:git:*' user-commands ${${(M)${(k)commands}:#git-*}/git-/}

function git-shortrev {
    git rev-parse --short HEAD | head -c 7
}
