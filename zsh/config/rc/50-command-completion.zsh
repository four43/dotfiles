autoload -U compinit
compinit -d ~/.cache/zcompdump
zstyle ':completion:*:manuals'    separate-sections true
zstyle ':completion:*:manuals.*'  insert-sections   true
zstyle ':completion:*:man:*'      menu yes select

if whence -cp  poetry 2>&1 >/dev/null; then
    mkdir -p ~/.zfunc
    poetry completions zsh > ~/.zfunc/_poetry
fi

aws_completer_path="$(whence -cp aws_completer 2>&1)"
if [[ $? == 0 ]]; then
    autoload bashcompinit && bashcompinit
    complete -C "$aws_completer_path" aws
fi

fpath+=~/.zfunc
