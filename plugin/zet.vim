" zet.vim - Power your Zettelkasten with vim
" Maintainer: Adam Trimble
" Version: 0.1

if exists('g:zet_loaded')
  finish
endif
let g:zet_loaded = 1

command! ZetCreateEmptyLink call zet#create_empty_link("vsplit")
command! -range ZetCreateLink call zet#create_link("vsplit")
command! ZetNewNote call zet#create_note()
command! ZetOpenNextDay call zet#open_next_day()
command! ZetOpenPreviousDay call zet#open_previous_day()
command! ZetOpenToday call zet#open_today()

if exists('g:zet_user_mapping') == 0
  nnoremap <Leader>z<Leader> :ZetOpenToday<cr>
  nnoremap <Leader>zj :ZetOpenPreviousDay<cr>
  nnoremap <Leader>zk :ZetOpenNextDay<cr>
  nnoremap <Leader>zl :ZetCreateEmptyLink<cr>
  vnoremap L :ZetCreateLink<cr>
  nnoremap <Leader>zn :ZetNewNote<cr>
endif

if exists('g:zet_folder') == 0
  echom "You must define g:zet_folder for vim-zet to work properly"
elseif g:zet_folder[len(g:zet_folder) - 1] != '/'
  let g:zet_folder = g:zet_folder . '/'
endif

if exists('g:zet_file_extension') == 0
  let g:zet_file_extension = '.md'
elseif g:zet_file_extension[0] != '.'
  let g:zet_file_extension = '.' . g:zet_file_extension
endif
