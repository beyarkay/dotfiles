
" ------------------------------------------
"               WRITING THINGS
" ------------------------------------------

setlocal spell
set spelllang=en_gb
" Pressing Ctrl+L will fix spelling errors
inoremap <C-l> <c-g>u<Esc>[s1z=`]a<c-g>u

" ------------------------------------------
"               LATEX THINGS
" ------------------------------------------

" if you write your \label's as \label{fig:something}, then if you
" type in \ref{fig: and press <C-n> you will automatically cycle through
" all the figure labels. Very useful!
autocmd FileType tex setlocal iskeyword+=:
autocmd FileType tex setlocal tw=79
autocmd FileType tex setlocal spell


" ------------------------------------------
"               MARKDOWN THINGS
" ------------------------------------------
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
au BufEnter *.md setlocal tw=79
au BufEnter *.md setlocal spell

" ------------------------------------------
"               RUBY THINGS
" ------------------------------------------
autocmd Filetype ruby set foldmethod=syntax

" ------------------------------------------
"               PLUGIN THINGS
" ------------------------------------------
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

" LaTeX plugin
Plug 'lervag/vimtex'
let g:vimtex_fold_enabled=1
let g:tex_flavor='latex'
set conceallevel=1
let g:tex_conceal='abdmg'

" Git gutter for git diffs
Plug 'mhinz/vim-signify'

" default updatetime 4000ms is not good for async update
set updatetime=100

" OneHalfDark Theme
Plug 'sonph/onehalf', { 'rtp': 'vim' }

" Autocomplete style snippit engine
Plug 'SirVer/ultisnips'
" Snippet trigger configuration.
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<tab>"
let g:UltiSnipsJumpBackwardTrigger="<s-tab>"

" Typeing :UltiSnipsEdit will edit the current filetype's snippets, in a
" window split dependant on context
"let g:UltiSnipsEditSplit="context"

call plug#end()

" Esc in insert mode
inoremap kj <esc>


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
