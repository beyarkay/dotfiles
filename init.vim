" --------------------------------------------------
" Link up nvim so that it uses the .vimrc preference
" --------------------------------------------------
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc

" Customising fzf:
" Most commands support CTRL-T / CTRL-X / CTRL-V key bindings to open in a new
" tab, a new split, or in a new vertical split. Bang-versions of the commands
" (e.g. Ag!) will open fzf in fullscreen.

" Faster Rg search via :RG
function! RipgrepFzf(query, fullscreen)
  let command_fmt = 'rg --column --line-number --no-heading --color=always --smart-case -- %s || true'
  let initial_command = printf(command_fmt, shellescape(a:query))
  let reload_command = printf(command_fmt, '{q}')
  let spec = {'options': ['--phony', '--query', a:query, '--bind', 'change:reload:'.reload_command]}
  call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(spec), a:fullscreen)
endfunction
command! -nargs=* -bang RG call RipgrepFzf(<q-args>, <bang>0)

" Remap ctrl-p to :Files search for fzf
nnoremap <C-q> :Files<CR>
" Remap ctrl-g ripgrep search of everything
nnoremap <C-g> :RG<CR>
" Coc config (macOS only)
if has('mac') || has('macunix')
    " Install Coc language extensions
    let g:coc_global_extensions = [
      \ 'coc-clangd',
      \ 'coc-eslint',
      \ 'coc-fzf-preview',
      \ 'coc-git',
      \ 'coc-html',
      \ 'coc-java',
      \ 'coc-jedi',
      \ 'coc-json',
      \ 'coc-markdown-preview-enhanced',
      \ 'coc-marketplace',
      \ 'coc-rust-analyzer',
      \ 'coc-sh',
      \ 'coc-tsserver',
      \ 'coc-vimlsp',
      \ 'coc-webview',
      \ 'coc-yaml',
      \ ]


    " Use tab for trigger completion with characters ahead and navigate.
    " NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
    " other plugin before putting this into your config.
    inoremap <silent><expr> <TAB>
          \ pumvisible() ? "\<C-n>" :
          \ <SID>check_back_space() ? "\<TAB>" :
          \ coc#refresh()
    inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

    function! s:check_back_space() abort
      let col = col('.') - 1
      return !col || getline('.')[col - 1]  =~# '\s'
    endfunction

    " Make <CR> auto-select the first completion item and notify coc.nvim to
    " format on enter, <cr> could be remapped by other vim plugin
    inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                                  \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

    " Use `[g` and `]g` to navigate diagnostics
    " Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
    nmap <silent> [g <Plug>(coc-diagnostic-prev)
    nmap <silent> ]g <Plug>(coc-diagnostic-next)

    " GoTo code navigation.
    nmap <silent> <leader>d <Plug>(coc-definition)
    nmap <silent> <leader>i <Plug>(coc-implementation)
    nmap <silent> <leader>r <Plug>(coc-references)
    " Symbol renaming.
    nmap <silent> <leader>n <Plug>(coc-rename)
    " Apply AutoFix to problem on the current line.
    nmap <leader>f  <Plug>(coc-fix-current)^[:wa<CR>

    " https://www.reddit.com/r/rust/comments/qxgroi/ism9me0/
    " Applying codeAction to the selected region.
    " Example: `<leader>Aap` for current paragraph
    xmap <leader>A  <Plug>(coc-codeaction-selected)
    nmap <leader>A  <Plug>(coc-codeaction-selected)

    " Apply codeAction to current cursor position
    nmap <leader>a  <Plug>(coc-codeaction-cursor)

    command! -nargs=0 Format :call CocActionAsync('format')

    augroup HaskellFormatOnSave
      autocmd!
      autocmd BufWritePre *.hs :call CocActionAsync('format')
    augroup end

    " Use K to show documentation in preview window.
    nnoremap <silent> K :call <SID>show_documentation()<CR>
    function! s:show_documentation()
      if (index(['vim','help'], &filetype) >= 0)
        execute 'h '.expand('<cword>')
      elseif (coc#rpc#ready())
        call CocActionAsync('doHover')
      else
        execute '!' . &keywordprg . " " . expand('<cword>')
      endif
    endfunction

    " Change the virtual text hint to be similar to that of comments
    highlight CocInlayHint ctermfg='darkgrey'

    " Highlight the symbol and its references when holding the cursor.
    autocmd CursorHold * silent call CocActionAsync('highlight')
endif

" Mark .typ files as typst filetypes, for integration with the tinymist typst LSP
autocmd BufNewFile,BufRead *.typ setfiletype typst
