" --------------------------------------------------
" Link up nvim so that it uses the .vimrc preference
" --------------------------------------------------
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc

call plug#begin()
" Install Coc: https://github.com/neoclide/coc.nvim
Plug 'neoclide/coc.nvim', {'branch': 'release'}
call plug#end()

" Install Coc language extensions
let g:coc_global_extensions = [
  \ 'coc-clangd',
  \ 'coc-fzf-preview',
  \ 'coc-git',
  \ 'coc-html',
  \ 'coc-java',
  \ 'coc-json', 
  \ 'coc-ltex',
  \ 'coc-markdown-preview-enhanced',
  \ 'coc-marketplace',
  \ 'coc-pyright',
  \ 'coc-sh',
  \ 'coc-webview',
  \ 'coc-yaml',
  \ ]
