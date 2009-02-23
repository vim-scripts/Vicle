" vicle.vim:  Vim - Interpreter Command Line Editor. Use vim like a front-end
"             for edit commands and send it to an interactive interpreter open
"             in a GNU Screen session.
" Maintainer: Jose Figuero Martinez <coloso at gmail dot com>
" Version:    1.0.0
" License:    BSD
" Os:         Linux, *Unix (both require GNU Screen)
" History:
"   2009-02-23:
"   - Fixed a bad behavior when open/save history files
"   2009-02-19:
"   - Added the documentation
"   - Added save and load history
"   2009-02-18: Second release and stable version 1
"   - Better manage of history
"   - Commands for: clear and save history and set/get screen session vars
"   2009-02-13: Firt realease
"   - Send data to the screen session
"   - History of commands (cyclic and without limit of size)
"   - Multiple vicle within a vim execution (using tabedit for example)
"
" Usage:
" - Load a Screen session and then load an interpreter (ipython, irb, shell,
"   sbcl, clisp, etc., etc) in the shell:
"   % screen -S rubySession
"   % irb
"   >>
"
" - Open Vim with the vicle plugin and type a command:
"   puts "Ruby interpreter"
"
" - Type <C-c><C-c>  or <C-CR>  to send to the interpreter
" - If the identifiers of the screen are not set, you are going be asked for
"   it (put the session name and window number where your interpreter are.
"   All the windows in a Screen session have a unique number.
"   You can use TAB key for completion in the Session name):
"
"   Session name: rubySession
"   Window number: 0
"
"   After that, your vim buffer are going to be empty and in insert mode for
"   write more commands and sendit to the interpreter. In the screen window
"   you are going to see:
"   >> puts "Ruby interpreter"
"   Ruby interpreter
"   => nil
"
" - You scroll through the commands with the key <C-Up> and <C-Down>   just
"   like the history of the shell.
" - Usefull commands for manage the history:
"   :VicleHistoryClear
"   :VicleHistorySize
"   :VicleHistorySave
"   :VicleHistoryLoad
" - To change the screen name and window name use the command
"   :VicleSession
"
" - Some global variables that you can define in your .vimrc:
"   let g:vicle_session_name    = 'normal_session_name'
"   let g:vicle_session_window  = 'normal_session_window'
"
"   let g:vicle_hcs             = '~~~your_command_separator~~~'
"
" Tips:
" - If you want to send commands to a Ruby interpreter (irb), open a file like
"   work.rb or other with the extension .rb  or set the filetype manually
"   :set filetype=ruby
"
"   This apply to other languages supported by vim.
"
" InspiredOn:
"   Slime for Vim from Jonathan Palardy
"   http://technotales.wordpress.com/2007/10/03/like-slime-for-vim/
"   and the work of Jerris Welt
"   http://www.jerri.de/blog/archives/2006/05/02/scripting_screen_for_fun_and_profit/


if exists('g:vicle_loaded')
    finish
endif
let g:vicle_loaded=1

" Vim vicle history command separator
if !exists('g:vicle_hcs')
  let g:vicle_hcs = '~~~vvhcs~~~'
endif

"   -   -   -   -   -   -   -   -   -   -

" Send the text of the screen (all) to Screen
" TODO Separate this function and receibe lines

function! Vicle_send_command()
  let l:lines= getline(0,'$')
  call Vicle_send(l:lines)
  call Vicle_screen_clean()
  call Vicle_startinsert()
endfunction

function! Vicle_send(lines)
  if a:lines != ['']
    let l:text = substitute(join(a:lines, "\n") , "'", "'\\\\''", 'g'). "\n"
    call Vicle_up_svars()
    call Vicle_history_save_command(a:lines)
    echo system('screen -S ' . w:vicle_screen_sn . ' -p ' . w:vicle_screen_wn . " -X stuff '" . l:text . "'")
    unlet l:text
  endif
endfunction

function! Vicle_screen_clean()
  :exec 'normal ggdG'
endfunction

function! Vicle_screen_put(lines)
  call Vicle_screen_clean()
  call append(1, a:lines)
  " Remove extra line and go to end of file
  exec 'normal dd'
endfunction

function! Vicle_startinsert()
  startinsert
  exec 'normal G$'
endfunction

" Session vars

function! Vicle_screen_sessions(A, L, P)
  return system("screen -ls | awk '/Attached/ {print $1}' | cut -d '.' -f 2")
endfunction

function! Vicle_clean_svars()
    unlet w:vicle_screen_sn
    unlet w:vicle_screen_wn
endfunction

" Historial of commands
function! Vicle_eh() " exists history
  return exists('w:vicle_history')
endfunction

function! Vicle_history_clear(msg)
  if Vicle_eh()
    if (a:msg != '')
      echohl Identifier
      let l:res = confirm("Clear history?", "&no\n&yes", 1)
      echohl None
      if l:res != 1
        echohl Comment | echon a:msg | echohl None
      else
        return
      endif
    endif

    for l:item in w:vicle_history
      call remove(w:vicle_history, 0)
    endfor
    unlet w:vicle_history
    unlet w:vicle_h_pointer
    unlet w:vicle_h_len
  end

  let w:vicle_history   = []
  let w:vicle_h_pointer = 0
  let w:vicle_h_len     = 0
endfunction

function! Vicle_history_save_command(text)
  call add(w:vicle_history, a:text)
  let w:vicle_h_len     = w:vicle_h_len + 1
  let w:vicle_h_pointer = w:vicle_h_len
endfunction

function! Vicle_history_move(ud)
  if Vicle_eh()
    if w:vicle_h_len > 0
      if a:ud < 1 " up
        let w:vicle_h_pointer = w:vicle_h_pointer - 1
        if w:vicle_h_pointer < 0
          let w:vicle_h_pointer = w:vicle_h_len - 1
        endif
      else        " down
        let w:vicle_h_pointer = w:vicle_h_pointer + 1
        if !(w:vicle_h_pointer < w:vicle_h_len)
          let w:vicle_h_pointer = 0
        endif
      endif

      call Vicle_screen_put(w:vicle_history[w:vicle_h_pointer])
      call Vicle_startinsert()
    else
      return ''
    endif
  endif
endfunction

function! Vicle_history_size()
  if Vicle_eh()
    let l:s = 0
    for l:item in w:vicle_history
      for l:i in l:item
        let l:s = l:s + strlen(l:i) + 2
      endfor
    endfor
    let l:s = l:s + 2 " list pointers

    echohl Comment    | echon 'Vicle history size: '
    echohl Constant   | echon string(l:s)
    echohl Comment    | echon ' bytes' | echohl None
  endif
endfunction

function! Vicle_history_save()
  if Vicle_eh()
    try
      echohl Identifier
      let l:fname = input('History file (save): ', '', 'file')
      if l:fname
        echohl None
        let l:lt = []
        for l:list in w:vicle_history
          for l:i in l:list
            call add(l:lt, l:i)
          endfor
          let l:lt = l:lt + [g:vicle_hcs]
        endfor
        call writefile(l:lt, l:fname)
        unlet l:lt
        echohl Comment | echon 'History file '. l:fname .' saved'
      end
      echohl None
    catch
      echoe 'Error writing vim vicle history to file: ' . string(l:fname)
    endtry
  endif
endfunction

function! Vicle_history_load()
  if ! Vicle_eh()
    call Vicle_history_clear('')
  endif
  try
    echohl Identifier
    let l:fname = input('History file (load): ', '', 'file')
    if l:fname
      echohl None
      let l:lines = readfile(l:fname)
      let l:lt = []
      call Vicle_history_clear('')

      for l:line in l:lines
        if l:line != g:vicle_hcs
          call add(l:lt, l:line)
        else
          call Vicle_send(l:lt)
          unlet l:lt
          let l:lt = []
        endif
      endfor
      echohl Comment | echon 'History' . l:fname . 'file loaded'
    endif
    echohl None
  catch
    echoe 'Error loading vim vicle history file: ' . string(l:fname)
  endtry
endfunction

"""""""""""" Up vars
function! Vicle_up_svars()
  if !exists('w:vicle_default_loaded')
    let w:vicle_default_loaded = 1
    " Define the 2 vars!!
    if exists('g:vicle_session_name')
      let w:vicle_screen_sn = g:vicle_session_name
      let w:vicle_screen_wn = g:vicle_session_window
    endif

    call Vicle_history_clear('')
  end

  if !exists('w:vicle_screen_sn') || !exists('w:vicle_screen_wn')
    echohl Identifier
    let w:vicle_screen_sn = input('Session name: ', '', 'custom,Vicle_screen_sessions')
    let w:vicle_screen_wn = input('Window number: ', '0')
    echohl None
  end
endfunction

function! Vicle_session()
  call Vicle_clean_svars()
  call Vicle_up_svars()
endfunction

function! Vicle_session_vars()
  if exists('w:vicle_screen_sn')
    echohl Comment  | echon 'Screen Session/Window: '
    echohl Constant | echon w:vicle_screen_sn
    echohl Comment  | echon '/'
    echohl Constant | echon w:vicle_screen_wn
    echohl None
  endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" TODO Check if the new maps are alredy defined

" Maps for sending
nmap <C-c><C-c> :call Vicle_send_command()<CR>
imap <C-c><C-c> <ESC>:call Vicle_send_command()<CR>

if ! mapcheck('<C-CR>')
  nmap <C-CR> <C-c><C-c>
  imap <C-CR> <ESC><C-c><C-c>
endif

" Maps for history
nmap <C-Up> :call Vicle_history_move(-1)<CR>
imap <C-Up> <ESC><C-Up>
nmap <C-Down> :call Vicle_history_move(1)<CR>
imap <C-Down> <ESC><C-Down>

" Commands
command! -complete=command VicleSession call Vicle_session()
command! -complete=command VicleSessionVars call Vicle_session_vars()
command! -complete=command VicleHistoryClear call Vicle_history_clear('Vicle history cleared')
command! -complete=command VicleHistorySize call Vicle_history_size()
command! -complete=command VicleHistorySave call Vicle_history_save()
command! -complete=command VicleHistoryLoad call Vicle_history_load()
