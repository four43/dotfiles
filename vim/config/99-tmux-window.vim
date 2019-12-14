if exists('$TMUX')
    autocmd BufEnter * call system("tmux rename-window 'vim|" . expand("%:t") . "'")
    autocmd VimLeave * call system("tmux setw automatic-rename")
endif
