setopt SH_WORD_SPLIT

bindkey -v
bindkey '^R' history-incremental-search-backward

# Home and End keys
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '\eOH' beginning-of-line
bindkey '\eOF' end-of-line
