" --------------------------------------------------
" Link up nvim so that it uses the .vimrc preference
" --------------------------------------------------
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
