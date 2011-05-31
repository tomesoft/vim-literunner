" Vimball Archiver by Charles E. Campbell, Jr., Ph.D.
UseVimball
finish
autoload/liteRunner.vim	[[[1
580
" File: autoload/liteRunner.vim
" Version: 0.3
"
" liteRunner plugin 
"
" Supports Edit,Run,Edit cycle of your scripting
"

"
" functions
"

" update or add entry of the ftyps_cmds_dict
" value type is expected list or string
function! liteRunner#UpdateFtypsCmdsEntry(key, value)
    let g:liteRunner_ftyps_cmds_dict[a:key] = 
                \ type(a:value) == type([]) ? a:value :
                \ type(a:value) == type('') ? [a:value] :
                \ []
endfunction

" update or add entry of the prognames_efms_dict
" value type is expected list or string
function! liteRunner#UpdatePrognamesEfmsEntry(key, value)
    let g:liteRunner_prognames_efms_dict[a:key] = 
                \ type(a:value) == type([]) ? a:value :
                \ type(a:value) == type('') ? [a:value] :
                \ []
endfunction

"holds script arguments that ran lastly
let b:liteRunner_held_script_arguments=[]

" expand the held arguments
function! liteRunner#ExpandHeldScriptArguments()
    if exists("b:liteRunner_held_script_arguments")
        return join(b:liteRunner_held_script_arguments, ' ')
    else
        return ''
    endif
endfunction

" edit the arguments without running
function! s:EditHeldArgumentsInCmdline()
    let heldtxt=join(b:liteRunner_held_script_arguments, ' ')
    call inputsave()
    let intxt=input('(edit args): ', heldtxt)
    call inputrestore()
    let b:liteRunner_held_script_arguments = split(intxt)
endfunction

" RunScript function called via Command
function! liteRunner#RunScript(rstart, rend, ...)
    " save arguments to use later in RunScriptWithHeldArguments()
    let b:liteRunner_held_script_arguments=a:000
    call s:RunScriptImpl(b:liteRunner_held_script_arguments, [a:rstart, a:rend],
                \ {})
endfunction

" RunScriptWithHeldArguments function called via Command
function! liteRunner#RunScriptWithHeldArguments(rstart, rend)
    let arg=[]
    if exists("b:liteRunner_held_script_arguments")
        let arg=b:liteRunner_held_script_arguments
        let arg= type(arg) == type([]) ? arg : [arg]
    endif
    call s:RunScriptImpl(arg, [a:rstart, a:rend],
                \ {})
endfunction

" RunScriptInteractively function calld via Command
function! liteRunner#RunScriptInteractively(rstart, rend)
    call s:RunScriptImpl([], [a:rstart, a:rend],
                \ {'interactively':1})
endfunction
"
" RunScriptInteractivelyWithEntireOfContent function calld via Command
function! liteRunner#RunScriptInteractivelyWithEntireOfContent()
    call s:RunScriptImpl([], [],
                \{'interactively':1, 'withEntireContent':1})
endfunction


" analyze the shebang line and returns their command line string
function! s:GetShebangCommand()
    let cmd = ''
    let line=getline(1)
    if line =~ '^#!'
        let lstoken=split(line[2:])
        if len(lstoken) == 0
            let cmd='/usr/bin/env sh'
        else
            let cmd=join(lstoken, ' ')
        endif
    endif
    return cmd
endfunction

function! s:GetCommandListFromFtypsCmdsDict()
    return get(g:liteRunner_ftyps_cmds_dict, &filetype, [])
endfunction

"
function! s:RunScriptImpl(lsargs, lrange, options)
    let cmd = ''
    let interactively = get(a:options, 'interactively', 0)
    let forcibly_with_entire_content = get(a:options, 'withEntireContent', 0)
    if g:liteRunner_tries_to_use_shebang
        "try to find shebang #! of current buffer
        let cmd = s:GetShebangCommand()
    endif

    "shebang not found or not tried
    if empty(cmd)
        let lstcmd=s:GetCommandListFromFtypsCmdsDict()
        if empty(lstcmd)
            call s:echo_warn("cannot run the typeof " . (!empty(&filetype) ? &filetype : '*None*'))
        else
            let cmd = get(lstcmd, (interactively? 1 : 0), lstcmd[0])
        endif
    endif

    if !empty(cmd)
        let bufhdr = s:GetProgname(cmd)
        if interactively
            call s:RunCurrentBufferInteractively(cmd, bufhdr, a:lsargs, a:lrange,
                        \ forcibly_with_entire_content)
        else
            call s:RunCurrentBufferAsScript(cmd, bufhdr, a:lsargs, a:lrange)
        endif
        let consumed =1
    endif
endfunction


"
" run current buffer as a script file 
"
function! s:RunCurrentBufferAsScript(cmd, bufheader, lsargs, lrange)
    let buftitle=a:bufheader . " output"
    let fpath=expand("%")
    let fname=expand("%:t")
    if empty(fname)
        call s:echo_warn("save at first!!")
    else
        let buftitle = "[" . buftitle . "][" . fname . "]"
        w%
        call s:RunScriptFile(a:cmd, fpath, buftitle, a:lsargs)
    endif
endfunction

" if an interactive buffer (which is tied to current buffer) is alive,
" returns bufnr, otherwise returns 0
function! s:GetAliveInteraciveBufferNumber()
    if exists("b:liteRunner_interactive_bufnr")
                \ && buflisted(b:liteRunner_interactive_bufnr)
                \ && bufloaded(b:liteRunner_interactive_bufnr)
        return b:liteRunner_interactive_bufnr
    endif
    return 0
endfunction

let s:liteRunner_conque_term_registered = 0
function! s:RegisterCallbacks()
    if !s:liteRunner_conque_term_registered
        call conque_term#register_function('after_startup', 'liteRunner#AfterStartupConqueTerm')
        let s:liteRunner_conque_term_registered = 1
    endif
endfunction


function! liteRunner#AfterStartupConqueTerm(conqterm)
    let conq = a:conqterm
    "call s:echo_warn('after startup idx='. conq['idx'])
    if exists('b:liteRunner_input_queue') && !empty(b:liteRunner_input_queue)
        lockvar b:liteRunner_input_queue 1
        for ent in b:liteRunner_input_queue
            call conq.writeln(ent)
        endfor
        let b:liteRunner_input_queue = []
        unlockvar b:liteRunner_input_queue
    endif
    let b:liteRunner_conque_term_loaded = 1
endfunction

function! s:echo_warn(msg)
    echohl WarningMsg | echo a:msg | echohl None
endfunction

function! s:EnqueInputOfConqueTerm(conqterm, text_or_lines)
    call s:echo_warn('Enqueued.')
    if !exists('b:liteRunner_input_queue')
        let b:liteRunner_input_queue = []
    endif
    lockvar b:liteRunner_input_queue 1
    let b:liteRunner_input_queue += text_or_lines
    unlockvar b:liteRunner_input_queue
endfunction


" wait to stable input
function! s:WaitUntilCannotRead(conqterm, timeout, step)
    let conq = a:conqterm
    let elaps = 0
    while a:timeout > elaps
        let tick = getbufvar('%', 'changedtick')
        call conq.read(a:step)
        if tick != getbufvar('%', 'changedtick')
            "call s:echo_warn('reset **')
            let elaps=0
        endif
        let elaps += a:step
    endwhile
endfunction

" input to conque_term
function! s:InputToConqueTerm(conqterm, text_or_lines)
    let conq = a:conqterm
    let text_or_lines = a:text_or_lines

    if !exists("b:liteRunner_conque_term_loaded")
        call EnqueInputOfConqueTerm(conq, text_or_lines)
        return
    endif

    if !empty(conq) && !empty(text_or_lines)
        "call s:WaitUntilCannotRead(conq, 3000, 1)
        "call conq.read(5000)
        if type(text_or_lines) == type('')
            call conq.write(text_or_lines)
        elseif type(text_or_lines) == type([])
            "for ln in text_or_lines | call conq.writeln(ln) | endfor
            " to solve a deadlock problem, insert conq.read(1)
            for ln in text_or_lines | call conq.writeln(ln) | call conq.read(1) | endfor
        endif
        call conq.read(100)
        "call s:WaitUntilCannotRead(conq, 500, 1)
    endif
endfunction

" returns list [bufnr, conque_term_idx]
function! s:PrepareInteractiveBuffer(cmd)
    call s:RegisterCallbacks()
    let cbufno = bufnr('%')
    let ibufno = s:GetAliveInteraciveBufferNumber()
    if ibufno
        let idx=getbufvar(cbufno, "liteRunner_conque_term_index")
        if !empty(idx)
            let conq = conque_term#get_instance(idx)
            if !empty(conq) && get(conq, 'active', 0)
                        \ && (get(conq, 'command', '') == a:cmd)
                "already alive
                if !g:liteRunner_ConqueTerm_renew_everytime
                    return [ibufno,idx] "reuse
                endif
                "call conq.close() " happens mapping errors
            endif
        endif
        execute ibufno."bwipeout!"
        let ibufno = 0
    endif

    if !ibufno
        if exists("g:liteRunner_ConqueTerm_command")
            execute g:liteRunner_ConqueTerm_command . ' ' . a:cmd
        else
            call conque_term#open(a:cmd, ['below split', 'resize '.
                        \ g:liteRunner_windowheight_max])
        endif
        " if buffer moved, that is succeeded to execute the program (maybe)
        if cbufno != bufnr('%')
            let ibufno = bufnr('%')
            call setbufvar(cbufno, "liteRunner_interactive_bufnr", ibufno)
            let conq = conque_term#get_instance()
            let idx = get(conq, 'idx', 0)
            call setbufvar(cbufno, "liteRunner_conque_term_index", idx)
            call s:SetOwnerBuffer(ibufno, cbufno)
            if has('localmap')
                " buffer local map <CR> jump back to previous window
                "nnoremap <silent> <buffer> <CR> :wincmd p<CR>
                nnoremap <silent> <buffer> <CR> :call liteRunner#JumpToOwnerBuffer()<CR>
            endif
            "TODO: To solve a problem that is lacked the first input line, in gvim on Windows
            call s:WaitUntilCannotRead(conq, 2000, 1)
            return [ibufno, idx]
        endif
    endif

    return []
endfunction

" returns string or list of lines
function! s:GetPassingTextOrLines(lrange, mode)
    let pass_mode = a:mode
    if pass_mode == 0 | return '' | endif

    if pass_mode <= 2
        "TODO: need to respond the select mode
        let lastVisualMode = visualmode(" ") "get and clear visualmode
        if empty(lastVisualMode) && (a:lrange[0] != 1 || a:lrange[1] != line('$'))
            "given the specific range e.g. /^#/,5
            return getline(a:lrange[0], a:lrange[1])
        endif

        if !empty(lastVisualMode)
            "if lastVisualMode == 'v' or <C-V> blockmode
            let svreg = @@
            " redo the visual selection and yank it
            silent execute 'normal! gvy'
            let lresult = split(@@, '[\r\n]')
            let @@ = svreg
            call visualmode(' ') "clear last visualmode
            return lresult
        endif
    endif

    if pass_mode >= 2
        "pass entire contents (exclude shebang line)
        return getline(s:GetShebangCommand() != '' ? 2 : 1, '$')
    endif

    return ''
endfunction

"
" run contents of current buffer interactively
"
function! s:RunCurrentBufferInteractively(cmd, bufheader, lsargs, lrange, withEntireContent)
    if !exists(':ConqueTerm')
        call s:echo_warn('ConqueTerm plugin required!')
        return
    endif

    let pass_mode = a:withEntireContent ? 3 :
                \ exists("g:liteRunner_ConqueTerm_content_pass_mode") ?
                \ g:liteRunner_ConqueTerm_content_pass_mode : 1
    let text_or_lines = s:GetPassingTextOrLines(a:lrange, pass_mode)
    let cmd=s:PreprocessCommandLine(a:cmd)
    " expands (%) in cmd
    let cmd=s:ExpandWithSpecifiedPath(cmd, expand('%:t'))

    let lbufspec = s:PrepareInteractiveBuffer(cmd)
    if !empty(lbufspec)
        " jump to the interactive buffer
        let winnr = bufwinnr(lbufspec[0])
        if winnr != bufwinnr(bufnr('%'))
            execute winnr . 'wincmd w'
        endif

        "let svmode = mode()
        "change to normal mode before write something
        stopinsert
        "if svmode == 'i'
            "stopinsert
        "endif
        
        " do input
        let conq = conque_term#get_instance(lbufspec[1])
        "call s:echo_warn(conq)
        "call s:echo_warn('liteRunner_conque_term_loaded='. getbufvar('%', 'liteRunner_conque_term_loaded'))
        if !empty(conq) && !empty(text_or_lines)
            call s:InputToConqueTerm(conq, text_or_lines)
        endif

        " restore insert mode
        "if svmode == 'i'
            "startinsert!
        "endif
        startinsert!
    endif
endfunction

" get program name from cmdline string
" e.g '/usr/local/bin/python2.3' -> python2.3
" e.g '/usr/bin/env python' -> python
" e.g 'python3.2.exe' -> python3.2
function! s:GetProgname(cmd)
    let lcmd=split(a:cmd, ' ')
    let pn=fnamemodify(
                \ len(lcmd) > 1 && fnamemodify(lcmd[0], ':t') == 'env' ? lcmd[1] : lcmd[0],
                \ ':t')
    return fnamemodify(pn, ':e') == 'exe' ? fnamemodify(pn, ':r') : pn
endfunction

" if (%) in src, it replaces into path
function! s:ExpandWithSpecifiedPath(str, path)
    let lst=matchlist(a:str, '\([^(]*\)\((%[^)]*)\)\(.*\)')
    if empty(lst)
        return a:str
    endif
    return lst[1] . fnamemodify(a:path, lst[2][2:-2]) . s:ExpandWithSpecifiedPath(lst[3], a:path)
endfunction

" find a buffer with title
function! s:FindBufferWithTitle(title)
    "try to find via bufnr
    let nr=bufnr(a:title)
    if nr > 0 && bufname(nr) == a:title
        return nr
    endif
    "confirm buffer list in current tab
    for n in tabpagebuflist()
        if bufname(n) == a:title
            return n
        endif
    endfor
    return -1
endfunction

" search in g:liteRunner_prognames_efms_dict
function! s:GetCustomErrorFormatByProgname(progname)
    "try to get with detail name to more common name
    "e.g [python2.6, python2, python]
    let lpatterns = []
    let lpn = split(a:progname, '\.')
    " eliminate '.' separated parts from tail
    while len(lpn) > 0
        let lpatterns += [join(lpn, '.')]
        let lpn = lpn[:-2]
    endwhile
    " eliminate version numbers
    while len(lpatterns[-1]) > 1 && lpatterns[-1] =~ '\d$'
        let lpatterns += [lpatterns[-1][0:-2]]
    endwhile

    for n in lpatterns
        let lsefm = get(g:liteRunner_prognames_efms_dict, n, [])
        if len(lsefm) > 0
            return lsefm
        endif
    endfor
    return [] "not found
endfunction

"
" check whether a valid entry in Quickfix
" now checks line number of entries
function! s:ContainsValidEntryInQuickfix()
    for ent in getqflist()
        if get(ent, 'lnum', 0) > 0
            return 1
        endif
    endfor
    return 0
endfunction

" set up an output buffer
function! s:PrepareOutputBuffer(buftitle)
    let ownerbufno = bufnr('%')
    execute '5new ' . a:buftitle
    execute 'resize '. g:liteRunner_windowheight_default
    set number
    setlocal bufhidden=delete "delete this buffer when hide
    setlocal noswapfile
    "change buftype to nofile to make no effect on chdir
    set buftype=nofile
    let bufno = bufnr('%')
    " set relationship to owner
    call s:SetOwnerBuffer(bufno, ownerbufno)
    if has('localmap')
        " buffer local map <CR> jump back to previous window
        "nnoremap <silent> <buffer> <CR> :wincmd p<CR>
        nnoremap <silent> <buffer> <CR> :call liteRunner#JumpToOwnerBuffer()<CR>
    endif
    return bufno
endfunction

"
" run script file and the result shown in another window
"
function! s:RunScriptFile(cmd, fpath, buftitle, lsargs)
    let cmd=a:cmd
    let arg=len(a:lsargs) > 0 ? ' ' . join(a:lsargs, ' ') : ''
    let buftitle=a:buftitle
    let buftitle0=fnameescape(buftitle)
    let bufno = s:FindBufferWithTitle(buftitle)
    if bufno > 0 && bufexists(bufno)
        execute bufno."bdelete!"
    endif

    if g:liteRunner_shows_quickfix_on_error
        execute ':cclose'
    endif

    "save splitbelow option to use below
    let save_sb=&splitbelow
    setlocal splitbelow

    "prepare output buffer
    call s:PrepareOutputBuffer(buftitle0)

    " try to get a custom errorformat
    let lsefm = s:GetCustomErrorFormatByProgname(s:GetProgname(cmd))
    if len(lsefm) > 0
        execute 'setlocal errorformat='.join(lsefm, ',')
    endif

    let cmd=s:PreprocessCommandLine(cmd)

    " expand (%) symbols
    let excmd=s:ExpandWithSpecifiedPath(cmd, a:fpath)

    if cmd != excmd
        echo ":r!" . excmd . arg
        silent execute "r!" . excmd . arg
    else
        echo ":r!" . cmd . ' ' . a:fpath . arg
        silent execute "r!" . cmd . ' ' . a:fpath . arg
    endif

    "remove first empty line
    execute ':0d'
    setlocal nomod
    
    let l:errors_in_quickfix=0
    "quickfix
    if g:liteRunner_checks_errors_always ||
                \ (v:shell_error && g:liteRunner_uses_quickfix_on_error)
        execute ':cgetbuffer'
        if s:ContainsValidEntryInQuickfix()
            let l:errors_in_quickfix=1
        endif
    endif

    "resize window height up to g:liteRunner_windowheight_max
    let max_winheight = min([line('$'), g:liteRunner_windowheight_max])
    if max_winheight > winheight(0)
        execute ':resize ' . max_winheight
    endif

    "restore splitbelow option
    let &splitbelow=save_sb
    if l:errors_in_quickfix
        execute 'wincmd p'
        if g:liteRunner_shows_quickfix_on_error
            execute ':copen'
        endif
        execute ':cc'
    else
        "stay cursor when buffer lines > winheight
        if line('$') > winheight(0)
            "stay in window
        else
            "back to previous window
            execute 'wincmd p'
        endif
    endif
endfunction

" make relationship between buffers
function! s:SetOwnerBuffer(childno, ownerno)
    if bufexists(a:childno) && bufexists(a:ownerno)
        call setbufvar(a:childno, "liteRunner_owner_bufnr", a:ownerno)
    endif
endfunction

" jump to the owner buffer
function! liteRunner#JumpToOwnerBuffer()
    let ownerno = getbufvar('%', "liteRunner_owner_bufnr")
    if !empty(ownerno) && bufexists(ownerno)
        execute bufwinnr(ownerno) . 'wincmd w'
    endif
endfunction

"make preprocess to cmdline before executing
function! s:PreprocessCommandLine(cmd)
    if has("win32")
        "TODO executable() check needed
        " in Windows cannot work /usr/bin/env
        let lcmd=split(a:cmd, ' ')
        if !executable(lcmd[0])
            if fnamemodify(lcmd[0], ':t') == 'env'
                return join(lcmd[1:], ' ') 
            endif
        endif
    endif
    return a:cmd
endfunction

"vim:ts=8:sts=4:sw=4:et
plugin/liteRunner.vim	[[[1
198
" File: plugin/liteRunner.vim
" Version: 0.3
"
" liteRunner plugin
"
" Supports Edit,Run,Edit cycle of your scripting
"
if exists("g:loaded_literunner")
    finish
endif
let g:loaded_literunner=1

"
" configurations
"
" flag tries to use shebang (#!...)
if !exists("g:liteRunner_tries_to_use_shebang")
    let g:liteRunner_tries_to_use_shebang=1
endif

" flag uses Quickfix on error
if !exists("g:liteRunner_uses_quickfix_on_error")
    let g:liteRunner_uses_quickfix_on_error=1
endif

" flag shows Quickfix window on error
if !exists("g:liteRunner_shows_quickfix_on_error")
    let g:liteRunner_shows_quickfix_on_error=1
endif

" flag checks errors always (includes exitcode=0)
if !exists("g:liteRunner_checks_errors_always")
    let g:liteRunner_checks_errors_always=0
endif

" output window height default
if !exists("g:liteRunner_windowheight_default")
    let g:liteRunner_windowheight_default=5
endif

" output window height max
if !exists("g:liteRunner_windowheight_max")
    let g:liteRunner_windowheight_max=10
endif

" ConqueTerm Command
"if !exists("g:liteRunner_ConqueTerm_command") && exists(":ConqueTerm")
    "let g:liteRunner_ConqueTerm_command='ConqueTermSplit'
"endif

" flag renew ConqueTerm everytime or not
if !exists("g:liteRunner_ConqueTerm_renew_everytime")
    let g:liteRunner_ConqueTerm_renew_everytime=0
endif

" 0=never passing, 1=selection only, 2=entire of content
if !exists("g:liteRunner_ConqueTerm_content_pass_mode")
    let g:liteRunner_ConqueTerm_content_pass_mode=1
endif

"
" dictionary of filetypes and commands
" key=filetype : value=[command-str, command-str-of-interactive]
" typically, editing file path is concatenated after command with whitespace.
" if (%) in command string, it replaced with editing file path.
" e.g. script -i=(%) --dir=(%:h)
if !exists("g:liteRunner_ftyps_cmds_dict")
    let ENVPROG='/usr/bin/env'
    if !executable(ENVPROG)
        " search env in path
        let ENVPROG = glob('`which env`')
    endif
    let ENV=''
    if !empty(ENVPROG)
        let ENV = ENVPROG.' '
    endif
    "TODO: maintain list
    let g:liteRunner_ftyps_cmds_dict={
        \'awk'      : [ENV.'awk -f'],
        \'lua'      : [ENV.'lua'],
        \'perl'     : [ENV.'perl'],
        \'php'      : [ENV.'php'],
        \'python'   : [ENV.'python'],
        \'ruby'     : [ENV.'ruby', ENV.'irb'],
        \'scheme'   : [ENV.'gosh', ENV.'gosh -i'],
        \'sed'      : [ENV.'sed -f'],
        \'sh'       : [ENV.'sh'],
        \'csh'      : [ENV.'csh'],
        \'tcsh'     : [ENV.'tcsh'],
        \'zsh'      : [ENV.'zsh'],
        \}

    if has('unix')
    elseif has('win32')
    endif
    " appendix : experimental
    if has('mac')
        let g:liteRunner_ftyps_cmds_dict['html'] = ['open']
    endif
    "let g:liteRunner_ftyps_cmds_dict['scheme'] = ['mit-scheme --load (%)']
endif

"
" dictionary of custom errorformat by progname
" key="progname" value=[list of errorformat]
"
if !exists("g:liteRunner_prognames_efms_dict")
    " for Python
    " in case of syntax error, traceback
    " checked version from 2.4 to 3.2.
    " column (by %p^) is not correct
    let s:python_efms=[
                \ '%A\ \ File\ \"%f\"\\,\ line\ %l',
                \ '%A\ \ File\ \"%f\"\\,\ line\ %l\\,\ %m',
                \ '%-C\ \ %p^',
                \ '%+C\ \ \ \ %s',
                \ '%+C%*[^\ :]%trror:\ %m',
                \]
    " for Gauche
    " checked version 0.9
    " in case of read-error, stack trace, debug-print
    " #?= is debug-print
    let s:gosh_efms=[
                \ 'gosh:\ \"read-%trror\":\ %*[^:]\ at\ \"%f\":line\ %l:\ %m',
                \ '\"%f\":%l:%m',
                \ '%Agosh:\ \"%*[^\"]-%trror\":\ %m',
                \ '%A#?=\"%f\":%l:%m',
                \ '%Agosh:\ \"%trror\":\ %m',
                \ '%+A%*[\ ]%*\\d\ %m',
                \ '%+C%*[\ ]At\ line\ %l\ of\ \"%f\"',
                \ '%Z#?-\ %m',
                \]
    " for Perl
    " experimental
    " checked version 5.12.3
    let s:perl_efms=[
                \ '%m\ at\ %f\ line\ %l.',
                \ '%m\ at\ %f\ line\ %l\\,\ near\ \"%*[^\"]\"',
                \ '%A%m\ at\ %f\ line\ %l\\,\ near\ \"%*[^\"]',
                \ '%Z%*[^\"]\"'
                \]
    
    " for Lua
    " experimental
    " checked version 5.1.4
    let s:lua_efms=[
                \ 'lua:\ %f:%l:\ %m'
                \]

    "TODO: maintain the list
    let g:liteRunner_prognames_efms_dict = {
                \ 'python' : s:python_efms,
                \ 'gosh'   : s:gosh_efms,
                \ 'perl'   : s:perl_efms,
                \ 'lua'    : s:lua_efms,
                \}
endif


"
" mappings
"
if !hasmapto('LRRunScriptInteractively')
    if mapcheck('<Leader>i') == ''
        :noremap <Leader>i :LRRunScriptInteractively<CR>
    endif
endif

if !hasmapto('LRRunScriptInteractivelyWithEntireOfContent')
    if mapcheck('<Leader>I') == ''
        :noremap <Leader>I :LRRunScriptInteractivelyWithEntireOfContent<CR>
    endif
endif

if !hasmapto('LRRunScriptWithHeldArguments')
    if mapcheck('<Leader>g') == ''
        :noremap <Leader>g :LRRunScriptWithHeldArguments<CR>
    endif
endif

if !hasmapto('LRRunScript ')
    if mapcheck('<Leader>G') == ''
        :noremap <Leader>G :<C-\>e("LRRunScript " . liteRunner#ExpandHeldScriptArguments())<CR>
    endif
endif
":noremap <script> <Leader>G :LREditHeldArguments<CR>

"
" commands
"
command! -nargs=* -range=% LRRunScript :call liteRunner#RunScript(<line1>, <line2>, <q-args>)
command! -nargs=0 -range=% LRRunScriptWithHeldArguments :call liteRunner#RunScriptWithHeldArguments(<line1>, <line2>)
command! -nargs=0 LREditHeldArguments :call liteRunner#EditHeldArgumentsInCmdline()
command! -nargs=0 -range=% LRRunScriptInteractively :call liteRunner#RunScriptInteractively(<line1>, <line2>)
command! -nargs=0 -range=% LRRunScriptInteractivelyWithEntireOfContent :call liteRunner#RunScriptInteractivelyWithEntireOfContent()


"vim:ts=8:sts=4:sw=4:et
