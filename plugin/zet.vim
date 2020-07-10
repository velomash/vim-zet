" zet.vim - The best way to take notes in vim
" Maintainer: Adam Trimble
" Version: 0.1

if exists('g:zet_loaded')
  finish
endif
let g:zet_loaded = 1

command! ZetCreateLink call zet#create_link()
command! ZetCreateNote call zet#create_note()
command! ZetOpenLink call zet#open_link()
command! ZetOpenToday call zet#open_today()
command! ZetSearchNotes call zet#search_notes()
command! ZetSearchBackLinks call zet#search_backlinks()

if exists('g:zet_user_mapping') == 0
  nnoremap <Leader>nl :ZetCreateLink<cr>
  nnoremap <Leader>nn :ZetCreateNote<cr>
  nnoremap <Leader>no :ZetOpenLink<cr>
  nnoremap <Leader>nt :ZetOpenToday<cr>
  nnoremap <Leader>ns :ZetSearchNotes<cr>
  nnoremap <Leader>nb :ZetSearchBackLinks<cr>
endif

if exists('g:zet_folder') == 0
  echom "You must define g:zet_folder for vim-zet to work properly"
endif
