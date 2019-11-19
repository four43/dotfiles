export PATH="$PATH:$DOTFILE_DIR/bin/git"

# Install autocomplete for git-* programs
zstyle ':completion:*:*:git:*' user-commands ${${(M)${(k)commands}:#git-*}/git-/}

function git-shortrev {
    git rev-parse --short HEAD
}
