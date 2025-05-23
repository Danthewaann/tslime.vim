" Tslime.vim. Send portion of buffer to tmux instance
" Maintainer: C.Coutinho <kikijump [at] gmail [dot] com>
" Licence:    DWTFYWTPL

if exists("g:loaded_tslime") && g:loaded_tslime
  finish
endif

let g:loaded_tslime = 1

" Function to send keys to tmux
" useful if you want to stop some command with <c-c> in tmux.
function! Send_keys_to_Tmux(keys)
  if !exists("g:tslime")
    call <SID>Tmux_Vars()
  endif

  let g:tslime["pane"] = 0
  if exists("g:tslime_pre_command")
    call system("tmux send-keys -t " . s:tmux_target() . " " . g:tslime_pre_command)
  endif
  call system("tmux send-keys -t " . s:tmux_target() . " " . a:keys)
endfunction

" Main function.
" Use it in your script if you want to send text to a tmux session.
function! Send_to_Tmux(text)
  if exists("g:tslime_autoset_pane") && g:tslime_autoset_pane
    call <SID>Tmux_Vars()
  endif
  call Send_keys_to_Tmux('"'.escape(a:text, '\"$').'"')
endfunction

function! s:tmux_target()
  return '"' . g:tslime['session'] . '":' . g:tslime['window'] . "." . g:tslime['pane']
endfunction

function! s:set_tmux_buffer(text)
  let buf = substitute(a:text, "'", "\\'", 'g')
  call system("tmux load-buffer -", buf)
endfunction

function! SendToTmux(text)
  call Send_to_Tmux(a:text)
endfunction

" Session completion
function! Tmux_Session_Names(A,L,P)
  return <SID>TmuxSessions()
endfunction

" Window completion
function! Tmux_Window_Names(A,L,P)
  return <SID>TmuxWindows()
endfunction

" Pane completion
function! Tmux_Pane_Numbers(A,L,P)
  if exists("g:tslime_autoset_pane") && g:tslime_autoset_pane
    return <SID>AutoTmuxPanes()
  else
    return <SID>TmuxPanes()
  endif
endfunction

function! s:ActiveTarget()
  return split(system('tmux list-panes -F "active=#{pane_active} #{session_name},#{window_index},#{pane_index}" | grep "active=1" | cut -d " " -f 2 | tr , "\n"'), '\n')
endfunction

function! s:TmuxSessions()
  if exists("g:tslime_always_current_session") && g:tslime_always_current_session
    let sessions = <SID>ActiveTarget()[0:0]
  else
    let sessions = split(system("tmux list-sessions -F '#{session_name}'"), '\n')
  endif
  return sessions
endfunction

function! s:TmuxWindows()
  if exists("g:tslime_always_current_window") && g:tslime_always_current_window
    let windows = <SID>ActiveTarget()[1:1]
  else
    let windows = split(system('tmux list-windows -F "#{window_index}" -t ' . g:tslime['session']), '\n')
  endif
  return windows
endfunction

function! s:TmuxPanes()
  let all_panes = split(system('tmux list-panes -t "' . g:tslime['session'] . '":' . g:tslime['window'] . " -F '#{pane_index}'"), '\n')

  " If we're in the active session & window, filter away current pane from
  " possibilities
  let active = <SID>ActiveTarget()
  let current = [g:tslime['session'], g:tslime['window']]
  if active[0:1] == current
    call filter(all_panes, 'v:val != ' . active[2])
  endif
  return all_panes
endfunction

function! s:AutoTmuxPanes()
  let valid_panes = {}
  let pane_heights = split(system('tmux list-panes -t "' . g:tslime['session'] . '":' . g:tslime['window'] . " -F '#{pane_height}'"), '\n')
  let c = 0
  for heights in pane_heights
    let valid_panes[c] = str2nr(heights)
    let c += 1
  endfor
  " If we're in the active session & window, filter away current pane from
  " possibilities
  let active = <SID>ActiveTarget()
  let current = [g:tslime['session'], g:tslime['window']]
  if active[0:1] == current
    call remove(valid_panes, active[2])
  endif
  " have to do this loop because max(valid_panes) doesn't work
  let biggest_height = 0
  let biggest_pane = -1
  for [index, height] in items(valid_panes)
    if height >= biggest_height
      let biggest_height = height
      let biggest_pane = index
    endif
  endfor
  if biggest_pane != -1
    return [biggest_pane]
  else
    return []
  endif
endfunction

" set tslime.vim variables
function! s:Tmux_Vars()
  let names = s:TmuxSessions()
  let g:tslime = {}
  if len(names) == 1
    let g:tslime['session'] = names[0]
  else
    let g:tslime['session'] = ''
  endif
  while g:tslime['session'] == ''
    let g:tslime['session'] = input("session name: ", "", "customlist,Tmux_Session_Names")
  endwhile

  " Create a new window or reuse an existing one to run the command in
  let windows = s:TmuxWindows()
  let current_window = system("tmux display-message -p '#I'")
  let next_window = current_window + 1
  if index(windows, string(next_window)) < 0
    call system('tmux new-window -a -c "#{pane_current_path}"')
  else
    call system('tmux select-window -t ' . next_window)
  endif

  let window = next_window
  let g:tslime['window'] = substitute(window, ":.*$" , '', 'g')

  if exists("g:tslime_autoset_pane") && g:tslime_autoset_pane
    let panes = s:AutoTmuxPanes()
  else
    let panes = s:TmuxPanes()
  endif

  if len(panes) == 1
    let g:tslime['pane'] = panes[0]
  else
    if !get(g:, "tslime_autoset_pane", 0)
      let g:tslime['pane'] = input("pane number: ", "", "customlist,Tmux_Pane_Numbers")
      if g:tslime['pane'] == ''
        let g:tslime['pane'] = panes[0]
      endif
    endif
  endif
endfunction

vnoremap <silent> <Plug>SendSelectionToTmux "ry :call Send_to_Tmux(@r)<CR>
nmap     <silent> <Plug>NormalModeSendToTmux vip<Plug>SendSelectionToTmux

nnoremap          <Plug>SetTmuxVars :call <SID>Tmux_Vars()<CR>

command! -nargs=* Tmux call Send_to_Tmux('<Args><CR>')

