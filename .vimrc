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
" Install Coc: https://github.com/neoclide/coc.nvim
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'sonph/onehalf', { 'rtp': 'vim' }

" Install a CSV colour scheme
Plug 'mechatroner/rainbow_csv'

" Formatting python files with `black`
" https://black.readthedocs.io/en/stable/integrations/editors.html#vim
Plug 'psf/black', { 'branch': 'stable' }

" Setup fzf for vim
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'

" Haskell formatting
Plug 'neovimhaskell/haskell-vim'
" The default color is white, which looks terrible
highlight CocFloating ctermbg=black
highlight Pmenu ctermfg=white ctermbg=black

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
nnoremap * *zz
nnoremap # #zz
" When going to the next/prior location, center the result
nnoremap <C-o> <C-o>zz
nnoremap <C-i> <C-i>zz

" Always use "very magic" regex search
nnoremap / /\v

" Allow saving of files as sudo when I forgot to start vim using sudo.
cmap w!! w !sudo tee > /dev/null %

set autoindent
set autowriteall
set background=dark
set backspace=indent,eol,start
" Copy to the MacOS Clipboard
set clipboard=unnamed
set cursorline
set expandtab
set foldmethod=indent
set foldlevel=99
set history=1000
set hlsearch
set ignorecase
set incsearch
set laststatus=2
set linebreak
" Enable mouse support
set mouse=a
set noerrorbells
set number
set nrformats=bin,hex,alpha,octal
set relativenumber
" Make vim start scrolling {scrolloff} characters before the end of the screen
set scrolloff=2
set shiftround
" Make vim horizontal scroll one char at a time, instead of jumping 100 characters
set sidescroll=1
" Make vim start horizontal scrolling {sidescrolloff} characters before the
" edge of the screen
set sidescrolloff=10
set smartcase
set smartcase
" Hardwrap the text at 79 characters
set textwidth=79
set timeoutlen=200
set title
set wildmenu

" Don't show the banner at the top of netrw
let g:netrw_banner = 0
" Show tree-style view by default
let g:netrw_liststyle = 3
let g:netrw_browse_split = 4
let g:netrw_altv = 1
let g:netrw_winsize = -25
" Highlight marked files in the same way as searches are
hi! link netrwMarkFile Search

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
au BufEnter *.md setlocal spell

" ====================================
" Set whitespace based on filetype
" https://stackoverflow.com/a/30114038
" ====================================
" By default, use 4 spaces
set shiftwidth=4
set softtabstop=4
set tabstop=4
" For some file types, use 2 spaces
autocmd FileType html setlocal ts=2 sts=2 sw=2 et
autocmd FileType ruby setlocal ts=2 sts=2 sw=2 et
autocmd FileType javascript setlocal ts=2 sts=2 sw=2 et
autocmd FileType typescript setlocal ts=2 sts=2 sw=2 et
autocmd FileType java setlocal ts=2 sts=2 sw=2 et

" Remap :W to write the file, and then run the Makefile in the background
command! W w|call jobstart('make&')

" ===================
" Format code on save
" ===================

" For java, cpp, use [clang-format](https://clang.llvm.org/docs/ClangFormat.html)
function! FormatClangOnSave()
    " Might require `python3 -m pip install --user --upgrade pynvim`
    " from https://stackoverflow.com/a/67360265/14555505
    let l:formatdiff = 1
    try
        py3f /usr/local/Cellar/clang-format/13.0.1/share/clang/clang-format.py
    catch
        py3f /opt/homebrew/Cellar/clang-format/14.0.0/share/clang/clang-format.py
    endtry
endfunction
autocmd BufWritePre *.java,*.h,*.cc,*.cpp call FormatClangOnSave()

augroup black_on_save
  autocmd!
  autocmd BufWritePre *.py Black
augroup end

" Plug 'rust-lang/rust.vim'
" let g:rustfmt_autosave = 1
