if exists('g:loaded_asr')
  finish
endif
let g:loaded_asr = 1

" Set up the keybinding
nnoremap <silent> <C-w> :lua require('asr').toggle_recording()<CR>
