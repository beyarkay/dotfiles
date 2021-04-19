" Setup proper folding for markdown files
function MarkdownLevel()
    let h = matchstr(getline(v:lnum), '^#\+')
    if empty(h)
        return "="
    else
        return ">" . len(h)
    endif
endfunction
au BufEnter *.md setlocal foldexpr=MarkdownLevel()
au BufEnter *.md setlocal foldmethod=expr

autocmd Filetype ruby set foldmethod=syntax     " Use manual folding for *.md files

if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif
call plug#begin('~/.vim/plugged')
" Git gutter for git diffs
Plug 'mhinz/vim-signify'
" default updatetime 4000ms is not good for async update
set updatetime=100
" OneHalfDark Theme
Plug 'sonph/onehalf', { 'rtp': 'vim' }
call plug#end()


autocmd BufNewFile,BufRead *.md set filetype=markdown   " Make sure ViM knows what markdown is
autocmd Filetype markdown set foldmethod=manual     " Use manual folding for *.md files

set t_Co=256
colorscheme onehalfdark

set autoindent
set autowriteall
set background=dark
set backspace=indent,eol,start
set clipboard=unnamed               " Copy to the MacOS Clipboard
set cursorline
set expandtab
set foldlevel=99
set foldmethod=indent
set history=1000
set hlsearch
set ignorecase
set incsearch
set laststatus=2
set linebreak
set noerrorbells
set number
set relativenumber
set scrolloff=5                                 " Make vim start scrolling {scrolloff} characters before the end of the screen
set shiftround
set shiftwidth=4
set sidescroll=1                                " Make vim horizontal scroll one char at a time, instead of jumping 100 characters
set sidescrolloff=10                            " Make vim start horizontal scrolling {sidescrolloff} characters before the edge of the screen
set smartcase
set smartcase
set tabstop=4
set timeoutlen=200
set title
set wildmenu
syntax on
