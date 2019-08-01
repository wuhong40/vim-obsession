" obsession.vim - Continuously updated session files
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.0

if exists("g:loaded_obsession") || v:version < 700 || &cp
  finish
endif
let g:loaded_obsession = 1

command! -bar -bang -complete=file -nargs=? Obsession
      \ execute s:dispatch(<bang>0, <q-args>)

function! s:get_session_path()
	set shellslash
    let cache_dir = expand($HOME) . "/.cache/vim/"

    if !isdirectory(cache_dir)
        call mkdir(cache_dir)
    endif

	let cwd = substitute(getcwd(), '/', '_', 'g')
	let cwd = substitute(cwd, ':', '_', 'g')
	let dir = cache_dir . cwd . '/'

    if !isdirectory(dir)
        call mkdir(dir)
    endif

	if g:is_os_windows
		set noshellslash
	endif

    return dir . "/Session.vim"
endfunction

function! s:dispatch(bang, file) abort
  let session = get(g:, 'this_obsession', v:this_session)
  try
    if a:bang && empty(a:file) && filereadable(session)
      echo 'Deleting session in '.fnamemodify(session, ':~:.')
      call delete(session)
      unlet! g:this_obsession
      return ''
    elseif empty(a:file) && exists('g:this_obsession')
      echo 'Pausing session in '.fnamemodify(session, ':~:.')
      unlet g:this_obsession
      return ''
    elseif empty(a:file) && !empty(session)
      let file = session
    elseif empty(a:file)
      " let file = getcwd() . '/Session.vim'
      let file = s:get_session_path()
    elseif isdirectory(a:file)
      " let file = substitute(fnamemodify(expand(a:file), ':p'), '[\/]$', '', '')
            " \ . '/Session.vim'
      let file = s:get_session_path()
    else
      let file = fnamemodify(expand(a:file), ':p')
    endif
    if !a:bang
      \ && file !~# 'Session\.vim$'
      \ && filereadable(file)
      \ && getfsize(file) > 0
      \ && readfile(file, '', 1)[0] !=# 'let SessionLoad = 1'
      return 'mksession '.fnameescape(file)
    endif
    let g:this_obsession = file
    let error = s:persist()
    if empty(error)
      echo 'Tracking session in '.fnamemodify(file, ':~:.')
      let v:this_session = file
      return ''
    else
      return error
    endif
  finally
    let &l:readonly = &l:readonly
  endtry
endfunction

function! s:persist() abort
  if exists('g:SessionLoad')
    return ''
  endif

  if &ft == ""
    return ''
  endif

  if exists('g:obsession_blacklist_fts') && has_key(g:obsession_blacklist_fts, &ft)
    return ''
  endif

  let sessionoptions = &sessionoptions
  if exists('g:this_obsession')
    try
      set sessionoptions-=blank sessionoptions-=options sessionoptions+=tabpages
      execute 'mksession! '.fnameescape(g:this_obsession)
      let body = readfile(g:this_obsession)
      call insert(body, 'let g:this_session = v:this_session', -3)
      call insert(body, 'let g:this_obsession = v:this_session', -3)
      call insert(body, 'let g:this_obsession_status = 2', -3)
      call writefile(body, g:this_obsession)
      let g:this_session = g:this_obsession
    catch
      unlet g:this_obsession
      let &l:readonly = &l:readonly
      return 'echoerr '.string(v:exception)
    finally
      let &sessionoptions = sessionoptions
    endtry
  endif
  return ''
endfunction

function! ObsessionStatus(...) abort
  let args = copy(a:000)
  let numeric = !empty(v:this_session) + exists('g:this_obsession')
  if type(get(args, 0, '')) == type(0)
    if !remove(args, 0)
      return ''
    endif
  endif
  if empty(args)
    let args = ['[$]', '[S]']
  endif
  if len(args) == 1 && numeric == 1
    let fmt = args[0]
  else
    let fmt = get(args, 2-numeric, '')
  endif
  return substitute(fmt, '%s', get(['', 'Session', 'Obsession'], numeric), 'g')
endfunction

function! s:auto_load_session()
  let session_path = s:get_session_path()
  if filereadable(session_path)
    exec "source " .session_path
  endif
endfunction

augroup obsession
  autocmd!
  au VimEnter * nested call s:auto_load_session()
  autocmd BufEnter,VimLeavePre * exe s:persist()
  autocmd User Flags call Hoist('global', 'ObsessionStatus')
augroup END

" vim:set et sw=2:
