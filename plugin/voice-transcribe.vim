if exists('g:loaded_voice_transcribe')
  finish
endif
let g:loaded_voice_transcribe = 1

" Set up the keybinding
nnoremap <silent> <C-w> :lua require('voice-transcribe').toggle_recording()<CR>