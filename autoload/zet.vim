" Location: autoload/zet.vim
" Author:   Adam Trimble
" Version:  0.1

let s:note_date_pattern = '^\d\{4}-\d\{2}-\d\{1,2}'
let s:note_id_pattern = '^\d\{4}-\d\{2}-\d\{1,2}-\d\+'

" UTIL FUNCTIONS
function! zet#get_todays_date()
  return strftime('%Y-%m-%d')
endfunction

function! zet#get_todays_note_id()
  let todaysDate = zet#get_todays_date()
  return todaysDate . "-0"
endfunction

function! zet#get_todays_note_ids()
  let note_ids = []
  let filenames = system("ls -1 " . g:zet_folder . "grep " . zet#get_todays_date())
  let filenames = split(filenames, "/n")
  for i in range(0, len(filenames) -1)
    if fnamemodify(filenames[i], ":e") === g:zet_file_extension[1:-1]
      let root = fnamemodify(filenames[i], ":r")
      call add(note_ids, root)
    endif
  endfor
  return note_ids
endfunction

function! zet#get_next_note_id()
  let todaysNoteIds = zet#get_todays_note_ids()
  let todaysDate = zet#get_todays_date()
  return todaysDate . "-" len(todaysNoteIds)
endfunction

function! zet#get_full_path(note_id)
  return g:zet_folder . a:note_id . g:zet_file_extension
endfunction

function! zet#get_sibling_daily_note(offset)
  let refNoteId = zet#get_current_note_date() . '-0'
  let daily_note_ids = []
  let filenames = system('ls -1 ' . g:zet_folder . ' | grep "\-0' . g:zet_file_extension . '"')
  let filenames = split(filenames, "/n")
  for i in range(0, len(filenames) -1)
    if matchstr(filenames[i], refNoteId)
      let refIndex = i
      return filenames[i + offset]
    endif
  endfor
  return filenames[len(filenames) - 1]
endfunction

function! zet#get_current_note_date()
  let currentNoteId = expand('%:t:r')
  return matchstr(currentNoteId, s:note_date_pattern)
endfunction

" NOTE FUNCTIONS
function! zet#open_today()
  let todaysNoteId = zet#get_todays_note_id()
  call zet#open_file("edit", zet#get_full_path(todaysNoteId))
endfunction

function! zet#open_previous_day()
  let nextDayId = zet#get_sibling_daily_note(-1)
  call zet#open_file("edit", zet#get_full_path(nextDayId))
endfunction

function! zet#open_next_day()
  let nextDayId = zet#get_sibling_daily_note(1)
  call zet#open_file("edit", zet#get_full_path(nextDayId))
endfunction


" --- LINK FUNCTIONS --------------------------------------------------------

" Move the cursor to the next or previous link in the buffer
function! zet#go_to_link(search_flags)
  let save_cursor = getcurpos()

  " Searching backward will not exclude the first match as long as it doesn't
  " start directly under the cursor. The following ugly hack is used to
  " position the cursor on the first chara of the link assuming it's on the
  " second, which will be the case after an automatic search
  if a:search_flags == 'b'
    normal! h
  endif

  call search(g:ntr_link_rx, a:search_flags)

  " if we found a link and jumped to it, move cursor to be inside the bracket
  if getcurpos() != save_cursor
    normal! l
  endif
endfunction

" Return the entire link (text included) under the cursor or -1 if there isn't
function! zet#get_link_under_cursor()
  let cur_col = col('.')
  let cur_line = getline('.')
  let temp_col = 0

  while 1
    let link_str = matchstrpos(cur_line, g:ntr_link_rx, temp_col)

    "if we can't find anymore link, we exit the function with failure
    if link_str[1] == -1
      return -1
    "if we find a link and the cursor is on, return the link
    elseif cur_col > link_str[1] && cur_col <= link_str[2]
      return link_str[0]
    "if we find a link but the cursor is not on, look for next link on line
    else
      let temp_col = link_str[2]
    endif
  endwhile
endfunction

" Go to the next link in the note. Repeated 'count' times
function! zet#next_link(count)
  let c = str2nr(a:count)
  while c > 0
    call zet#go_to_link('')
    let c -= 1
  endwhile
endfunction

" Go to the previous link in the note. Repeated 'count' times
function! zet#prev_link(count)
  let c = str2nr(a:count)
  while c > 0
    call zet#go_to_link('b')
    let c -= 1
  endwhile
endfunction


" --- OPEN FUNCTIONS --------------------------------------------------------

" Open the link under the cursor
function! zet#open_link(cmd)
  let link = zet#get_link_under_cursor()
  if link != -1
    let note_id = matchstr(link, '(\x\+)$')

    "if we found the note to open, update the history and open the note
    if note_id != ""
      call zet#open_file(a:cmd, zet#get_full_path(note_id[1:-2]))
    else
      echom "Error: cannot open note for link " . link
    endif
  endif
endfunction

" --- SEARCH FUNCTIONS -------------------------------------------------------

" Search or create a new note with FZF
function! zet#search_notes(cmd)
  call zet#run_fzf(zet#notes_content(), a:cmd, 0)
endfunction

" List all the links present in the current note
function! zet#search_links_in_note(cmd)
  let cur_file = expand('%:p')
  if cur_file == ""
    return
  endif

  " use an external command to get the list of links in the current file
  let links = system('rg -o -e "\[.+?\]\(.+?\)" ' . cur_file)
  let links = split(links, "\n")

  " format each link match to use it as input for fzf
  for i in range(0, len(links) - 1)
    let link = links[i]

    " get informations about the id part of the link. Return an array
    " [0] the string matching the pattern
    " [1] index of first char of the match
    " [2] index of last char of the match
    let id_info = matchstrpos(link, '(\x\{-})$')

    let id_part = id_info[0][1:-2] . " "
    let text_part = link[0:id_info[1] - 1]
    let links[i] = id_part . text_part
  endfor

  call zet#run_fzf(links, a:cmd, 0)
endfunction

" List all the notes linking to the current one
function! zet#search_notes_linking_here(cmd)
  let cur_file = expand('%:t:r')
  if cur_file == ""
    return
  endif

  " use external command rg to find links to the current note
  let results = system('rg -e "\[.+?\]\('.cur_file.'\)" '.g:zet_folder.'/*'.g:zet_file_extension)
  let results = split(results, "\n")

  " format the rg results to use as input of fzf
  for i in range(0, len(results) - 1)
    echom results[i]
    let res_parts = split(results[i], ":")
    let res_parts[1] = join(res_parts[1:-1], '')
    let res_filename = split(res_parts[0], "\/")[-1]
    let res_filename = fnamemodify(res_filename, ":r")
    let results[i] = res_filename . " " . res_parts[1]
  endfor

  call zet#run_fzf(results, a:cmd, 0)
endfunction

" List all the notes that are not linked anywhere
function! zet#search_orphan_notes(cmd)
  let linked_ids = []   " note ids that are present in a link somewhere
  let orphan_ids = []   " ids for notes that are not linked to anywhere
  let fzf_source = []   " list of strings used as source for fzf

  " perform a regex search once to get all links in every note
  let links = system('rg -oIN -e "\[.+?\]\([0-9a-f]+?\)" '.g:zet_folder.'/*'.g:zet_file_extension)
  let links = split(links, "\n")

  " strip those links to keep only the note id
  for i in range(0, len(links) - 1)
    let note_id = matchstr(links[i], '(\x\{-})$')
    let note_id = note_id[1:-2]
    call add(linked_ids, note_id)
  endfor

  " check for each note if it is referenced in a link or not
  let note_ids = zet#get_id_existing_notes()
  for i in range(0, len(note_ids) - 1)
    if index(linked_ids, note_ids[i]) == -1
      call add(orphan_ids, note_ids[i])
    endif
  endfor

  " format the results to be used as source for fzf
  for i in range(0, len(orphan_ids) - 1)
    let id = orphan_ids[i]
    let entry = id . " " . system('head -n 1 ' . g:zet_folder.id.g:zet_file_extension)
    call add(fzf_source, entry)
  endfor

  call zet#run_fzf(fzf_source, a:cmd, 0)
endfunction


" --- FZF RELATED FUNCTIONS --------------------------------------------------

" Return a list where each item is the content of a note. Formatted in a way
" that it can be used as a source for FZF
function! zet#notes_content()
  let note_ids = zet#get_id_existing_notes()
  let content = []

  for i in range(0, len(note_ids) - 1)
    let toAdd = note_ids[i]." ".system("cat ".g:zet_folder.note_ids[i].g:zet_file_extension)
    call add(content, toAdd)
  endfor
  
  call add(content, "NEW - select to create new note")
  return content
endfunction

" Function called with the selection of FZF
" param cmd is the command used to open the file
" param link_creation indicates what to do regarding link creation
" 0 - no link creation
" 1 - create link with visual selection
" 2 - create link without visual selection
" param e is the selection of FZF. The first word is the id of the note
function! zet#process_fzf_choice(cmd, link_creation, e)
  let note_id = split(a:e)[0]

  if note_id == "NEW"
    let note_id = zet#get_next_note_id()
  endif

  " if we choose to create a link with visual selection
  if a:link_creation == 1
    echom "about to execute in visual"
    exe "normal! \ei[\e`>la](" . note_id . ")\e"
  " if we choose to create a link without visual selection
  elseif a:link_creation == 2
    exe "normal! \ei[](" . note_id . ")\eF]"
  endif

  call zet#open_file(a:cmd, g:zet_folder."/".note_id.g:zet_file_extension)
endfunction

" Return a string with the options to use when running fzf
function! zet#get_fzf_opt()
  let o_pw = " --preview-window=down:60%:wrap"
  let o_p_base = "fmt {1}" . g:zet_file_extension
  let o_p = ' --preview="' . o_p_base . '"'
  let o_base = ' -e +m --cycle'
  let o_dsp = ' --no-bold --info="inline"'
  let o_col = " --color=border:#FF8888,hl:#FFF714,hl+:#FFF714"

  " apply user defined color scheme if it exists
  if exists('g:zet_color')
    let o_col = " " . g:zet_color
  endif

  return o_base . o_dsp . o_p . o_pw . o_col
endfunction

" Search for a note in all notes
function! zet#run_fzf(source, cmd, link_creation)
  call fzf#run({
    \ 'source': a:source,
    \ 'sink': function('zet#process_fzf_choice', [a:cmd, a:link_creation]),
    \ 'dir': g:zet_folder,
    \ 'options': zet#get_fzf_opt()
  \ })
endfunction


" --- HISTORY FUNCTIONS -----------------------------------------------------

" Open a file and update associated history
function! zet#open_file(cmd, filename)
  let new_history = getbufvar("%", "history", []) " get history of current buf
  call add (new_history, expand("%:p"))           " append filename of cur buf

  " always save the current buffer before opening the new one. Except when the
  " current buffer doesn't have a name
  if expand('%:t') != ""
    write
  endif

  exe a:cmd a:filename
  write
  call setbufvar("%", "history", new_history)     " set history on new buf
endfunction

" Go to the previous note in the history
function! zet#prev_note(cmd)
  let history = getbufvar("%", "history", []) " get history of current buf
  if len(history) <= 0                        " if no history we quit
    return
  endif
  exe a:cmd history[-1]
  if len(history) > 1                         " pop last item of history
    let history = history[0:-2]
  endif
  call setbufvar("%", "history", history)     " set history on new buf
endfunction


" --- CREATE FUNCTIONS ------------------------------------------------------

" Create a new note from selection and open it
function! zet#create_note(cmd)
  let note_id = zet#get_next_note_id()

  " delete the visual selection and write the empty link in place of
  let save_a = @a
  exe "normal! gv\"ad"
  exe "normal! \ei[](" . note_id . ")\eF]"

  " open the new note and paste content
  call zet#open_file(a:cmd, zet#get_full_path("/".note_id))
  exe "normal! \"ap"
  write

  let @a = save_a
endfunction

" Create a new empty note and open it
function! zet#create_empty_note(cmd)
  let note_id = zet#get_next_note_id()
  call zet#open_file(a:cmd, zet#get_full_path("/".note_id))
endfunction

" Create link to a note (selected through search or new) where the text is the
" visual selection
function! zet#create_link(cmd)
  call zet#run_fzf(zet#notes_content(), a:cmd, 1)
endfunction

" Create link without text to a note (selected through search or new)
function! zet#create_empty_link(cmd)
  call zet#run_fzf(zet#notes_content(), a:cmd, 2)
endfunction

" Return the list of IDs matching the notes in the note folder
function! notoire#get_id_existing_notes()
  let note_ids = []

  let filenames = system("ls -1 " . g:current_notoire_folder)
  let filenames = split(filenames, "\n")

  " check the filename is indeed a note and if yes keep only the id
  for i in range(0, len(filenames) - 1)
    if fnamemodify(filenames[i], ":e") == g:notoire_file_extension[1:-1]
      let root = fnamemodify(filenames[i], ":r")
      let match_hex = matchstr(root, '\x\+')
      if len(match_hex) == len(root)
        call add(note_ids, root)
      endif
    endif
  endfor

  return note_ids
endfunction
