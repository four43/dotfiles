" Huge performance boost if working in a terminal
set ttyfast

" Line number configuration -- this uses the configuration described at
" https://jeffkreeftmeijer.com/vim-number/ with some enhancements.
function Toggle_relativenumber_on()
    if &number
        set relativenumber
    end
endfunction

set number
set relativenumber

augroup numbertoggle
    autocmd!
    autocmd WinEnter,BufEnter,FocusGained,InsertLeave * call Toggle_relativenumber_on()
    autocmd WinLeave,BufLeave,FocusLost,InsertEnter   * set norelativenumber
augroup end


" Setup tabs
set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4
