" Minimal Vim configuration for server
syntax on
set tabstop=2
set shiftwidth=2
set expandtab
set number
set relativenumber
set hlsearch
set backspace=indent,eol,start
set nobackup
set nowritebackup
set noswapfile

" escape ESC
imap kj <Esc>

"split new buffers to right
set splitright

" automatically change working dir to active buffer's dir
set autochdir
