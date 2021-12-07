" ------------------
" Boyd Kane's .vimrc
" ------------------
"
" TODO:
" - Add syntax highlighting for trailing whitespace
"   (Or just remove it automatically on save)
" - A general tidy up is needed
" - Move over to nvim


" ------------------------------------------
"               WRITING THINGS
" ------------------------------------------

setlocal spell
set spelllang=en_gb
" Pressing Ctrl+l will fix spelling errors
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

if has('python3')
    " Autocomplete style snippit engine
    Plug 'SirVer/ultisnips'
    " Snippet trigger configuration.
    let g:UltiSnipsExpandTrigger="<tab>"
    let g:UltiSnipsJumpForwardTrigger="<tab>"
    let g:UltiSnipsJumpBackwardTrigger="<s-tab>"

    " Typeing :UltiSnipsEdit will edit the current filetype's snippets, in a
    " window split dependant on context
    "let g:UltiSnipsEditSplit="context"
endif
call plug#end()

set t_Co=256
colorscheme onehalfdark

" When searching, center the result
nnoremap n nzz
nnoremap N Nzz
" When going to the next/prior location, center the result
nnoremap <C-o> <C-o>zz
nnoremap <C-i> <C-i>zz


set autoindent
set autowriteall
set background=dark
set backspace=indent,eol,start
" Copy to the MacOS Clipboard
set clipboard=unnamed
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
" Make vim start scrolling {scrolloff} characters before the end of the screen
set scrolloff=2
set shiftround
set shiftwidth=4
" Make vim horizontal scroll one char at a time, instead of jumping 100 characters
set sidescroll=1
" Make vim start horizontal scrolling {sidescrolloff} characters before the edge of the screen
set sidescrolloff=10
set smartcase
set smartcase
set tabstop=4
set timeoutlen=200
set title
set wildmenu

" =======================================
" Setup proper folding for markdown files
" =======================================
function MdLevel()
    let h = matchstr(getline(v:lnum), '^#\+')
    if empty(h)
        return "="
    else
        return ">" . len(h)
    endif
endfunction
au BufEnter *.md setlocal foldexpr=MdLevel()
au BufEnter *.md setlocal foldmethod=expr
au BufEnter *.md setlocal tw=79
au BufEnter *.md setlocal spell

