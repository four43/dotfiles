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
bindkey '^[[3~' delete-char
bindkey '^?' backward-delete-char

# Ctrl+Left/Right for word navigation
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# Shift+Tab for reverse menu completion
bindkey '^[[Z' reverse-menu-complete

# Insert key
bindkey '^[[2~' overwrite-mode
