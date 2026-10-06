# Completion functions on $fpath must exist before compinit scans it
fpath=(~/.zfunc $fpath)
mkdir -p ~/.zfunc

# xwe-ai-tools (Click): write each CLI's completion function into ~/.zfunc
CLIS="jira confluence grib2-table tfdocs bbox remote-dev"
complete_var() { echo "_$(echo "$1" | tr 'a-z-' 'A-Z_')_COMPLETE"; }
for t in ${=CLIS}; do
    (( $+commands[$t] )) && env "$(complete_var "$t")=zsh_source" "$t" > ~/.zfunc/_"$t"
done

if whence -cp poetry 2>&1 >/dev/null; then
    poetry completions zsh > ~/.zfunc/_poetry
fi

autoload -U compinit
compinit -d ~/.cache/zcompdump
autoload bashcompinit && bashcompinit
zstyle ':completion:*:manuals'    separate-sections true
zstyle ':completion:*:manuals.*'  insert-sections   true
zstyle ':completion:*:man:*'      menu yes select

aws_completer_path="$(whence -cp aws_completer 2>&1)"
if [[ $? == 0 ]]; then
    complete -C "$aws_completer_path" aws
fi
