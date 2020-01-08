autoload -U compinit
compinit -d ~/.cache/zcompdump
zstyle ':completion:*:manuals'    separate-sections true
zstyle ':completion:*:manuals.*'  insert-sections   true
zstyle ':completion:*:man:*'      menu yes select

if whence -cp  poetry 2>&1 >/dev/null; then
    mkdir -p ~/.zfunc
    poetry completions zsh > ~/.zfunc/_poetry
fi

fpath+=~/.zfunc
