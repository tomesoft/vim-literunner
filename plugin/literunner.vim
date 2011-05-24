"
" liteRunner plugin v0.1 (tome@tomesoft.net)
"
" Supports edit-run-edit cycle
"
" In default, shebang (#!...) line in your editing file is used to run it, if exists.
"
" Usage:
" 1. You can put this file into ~/.vim/plugin/.
" 2. Add line to be loaded to your .vimrc
"    :runtime plugin/literunner.vim
" 3. In editing your script, key-in <Leader>g (in default, <Leader> mapped
"    to backslash '\') runs your script and the result is shown in output window.
" 4. If you need to pass some command line arguments when run it, key-in
"    <Leader>G, cusor then cusor jumps into command line
"     :LRRunscript 
"    input arguments (e.g. --help) and key-in return to run with the
"    arguments.
"     :LRRunscript --help
"    (is evaluated like as /usr/bin/env python myscript.py --help)
" 5. The specified arguments (in Step4) are held (buffer locally), and that
"    will be re-used on next run with <Leader>g until change them (using
"    <Leader>G) or finish editing.
" 
" Customize:
" 1.Mapping
" :noremap <Leader>g :LRRunScriptWithHeldArguments<CR>
" :noremap <Leader>G :<C-\>e("LRRunScript " . LiteRunner#ExpandHeldScriptArguments())<CR>
"   
" 2.Some variables are for customization, their prefix is g:liteRunner_XXX.
" TODO: explains each items
" g:liteRunner_tries_to_use_shebang=0 (bool=0,1)
" g:liteRunner_uses_quickfix_on_error=1 (bool=0,1)
" g:liteRunner_shows_quickfix_on_error=1 (bool=0,1)
" g:liteRunner_checks_errors_always=0 (bool=0,1)
" g:liteRunner_windowheight_default=5 (num)
" g:liteRunner_windowheight_max=10 (num)
" g:liteRunner_ftyps_cmds_dict={dict of defaults} (dict)
" g:liteRunner_prognames_efms_dict={dictjmap of defaults}
"
" 3.Some functions are for customization, their prefix is LiteRunner#XXX
" TODO: explains each item
" LiteRunner#UpdateFtypsCmdsEntry(key, value)
" LiteRunner#UpdateFtypsEfmsEntry(key, value)
" LiteRunner#ExpandHeldScriptArguments()
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

"
" dictionary of filetypes and cmds
" key=filetype : value=[command-str (,header-string-ofbuffer)]
" typically, editing file path is concatenated after command with whitespace.
" if (%) in command string, it replaced with editing file path.
" e.g. script -i=(%) --dir=(%:h)
if !exists("g:liteRunner_ftyps_cmds_dict")
	let g:liteRunner_ftyps_cmds_dict={
		\"scheme": ["/usr/bin/env gosh -i"],
		\"perl": ["/usr/bin/env perl"],
		\"python": ["/usr/bin/env python"],
		\"ruby": ["/usr/bin/env ruby"],
		\"lua": ["/usr/bin/env lua"],
		\"php": ["/usr/bin/env php"],
		\"sh": ["/usr/bin/env sh"],
		\"csh": ["/usr/bin/env csh"],
		\}

	if has('unix')
	elseif has('win32')
		" TODO: for win32 settings here
		let g:liteRunner_ftyps_cmds_dict={
			\"scheme": ["gosh -i"],
			\"perl": ["perl"],
			\"python": ["python"],
			\"ruby": ["ruby"],
			\"php": ["php"],
			\}
	endif
	" appendix : experimental
	if has('mac')
		let g:liteRunner_ftyps_cmds_dict["html"] = ["open", "open by os"]
	endif
endif

" update or add entry of the ftyps_cmds_dict
" value type is expected list or string
function! LiteRunner#UpdateFtypsCmdsEntry(key, value)
	let g:liteRunner_prognames_efms_dict[key] = 
				\ type(value) == type([]) ? value :
				\ type(value) == type('') ? [value] :
				\ []
endfunction

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
	let g:liteRunner_prognames_efms_dict = {
				\ 'python' : s:python_efms,
				\ 'gosh'   : s:gosh_efms,
				\ 'perl'   : s:perl_efms,
				\ 'lua'    : s:lua_efms,
				\}
endif

" update or add entry of the prognames_efms_dict
" value type is expected list or string
function! LiteRunner#UpdateFtypsEfmsEntry(key, value)
	let g:liteRunner_ftyps_cmds_dict[key] = 
				\ type(value) == type([]) ? value :
				\ type(value) == type('') ? [value] :
				\ []
endfunction


"
" mappings
"
if !hasmapto('LRRunScriptWithHeldArguments')
	if mapcheck('<Leader>g') == ''
		:noremap <Leader>g :LRRunScriptWithHeldArguments<CR>
	endif
endif
if !hasmapto('LRRunScript ')
	if mapcheck('<Leader>G') == ''
		:noremap <Leader>G :<C-\>e("LRRunScript " . LiteRunner#ExpandHeldScriptArguments())<CR>
	endif
endif
":noremap <script> <Leader>G :LREditHeldArguments<CR>

"
" commands
"
command! -nargs=* LRRunScript :call s:RunScript(<q-args>)
command! -nargs=0 LRRunScriptWithHeldArguments :call s:RunScriptWithHeldArguments()
command! -nargs=0 LREditHeldArguments :call s:EditHeldArgumentsInCmdline()



"
" functions
"
"holds script arguments that ran lastly
let b:liteRunner_held_script_arguments=[]

" expand the held arguments
function! LiteRunner#ExpandHeldScriptArguments()
	if exists("b:liteRunner_held_script_arguments")
		return join(b:liteRunner_held_script_arguments, ' ')
	else
		return ""
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


function! s:RunScript(...)
	" save arguments to use later in RunScriptWithHeldArguments()
	let b:liteRunner_held_script_arguments=a:000
	call s:RunScriptImpl(b:liteRunner_held_script_arguments)
endfunction

function! s:RunScriptWithHeldArguments()
	if exists("b:liteRunner_held_script_arguments")
		let arg=b:liteRunner_held_script_arguments
		if type(arg) == type([])
			call s:RunScriptImpl(arg)
		else
			call s:RunScriptImp([ arg ]) "(list arg) ->[arg]
		endif
	else
		call s:RunScriptImpl([])
	endif
endfunction

function! s:RunScriptImpl(lsargs)
	let l:consumed = 0
	if g:liteRunner_tries_to_use_shebang
		"try to find shebang #! of current buffer
		let line=getline(1)
		if line =~ '^#!'
			let lstoken=split(line[2:])
			if len(lstoken) == 0
				let cmd='/usr/bin/env sh'
				let bufhdr='sh'
			else
				let lscmd=split(lstoken[0], '/')
				if lscmd[-1] == 'env'
					let bufhdr=lstoken[1]
				else
					let bufhdr=lscmd[-1]
				endif
				let cmd=join(lstoken, ' ')
			endif
			call s:RunCurrentBufferAsScript(cmd, bufhdr, a:lsargs)
			let consumed =1
		endif
	endif

	"shebang not found or not tried
	if !consumed
		call s:RunScriptWithFileType(a:lsargs)
	endif
endfunction

"
" run script with filetype function
"
function! s:RunScriptWithFileType(lsargs)
	let ftyp = &filetype
	let lstcmd = get(g:liteRunner_ftyps_cmds_dict, ftyp, [])
	if empty(lstcmd)
		echohl WarningMsg | echo "cannot run the typeof " . (ftyp ? ftype : '*None*') | echohl None
	else
		let bufhdr = get(lstcmd, 1, s:GetProgname(lstcmd[0]))
		call s:RunCurrentBufferAsScript(lstcmd[0], bufhdr, a:lsargs)
	endif
endfunction


"
" run current buffer as a script file 
"
function! s:RunCurrentBufferAsScript(cmd, bufheader, lsargs)
	let buftitle=a:bufheader . " output"
	let fpath=expand("%")
	let fname=expand("%:t")
	if fname == ""
		echohl WarningMsg | echo "save first!!" | echohl None
	else
		let buftitle = "[" . buftitle . "][" . fname . "]"
		w%
		call s:RunScriptFile(a:cmd, fpath, buftitle, a:lsargs)
	endif
endfunction

" get progname from cmdline string
" e.g '/usr/local/bin/python2.3' -> python2.3
" e.g '/usr/bin/env python' -> python
" e.g 'python3.2.exe' -> python3.2
function s:GetProgname(cmd)
	let lcmd=split(a:cmd, ' ')
	let pn=fnamemodify(
				\ len(lcmd) > 1 && fnamemodify(lcmd[0], ':t') == 'env' ? lcmd[1] : lcmd[0],
				\ ':t')
	return fnamemodify(pn, ':e') == 'exe' ? fnamemodify(pn, ':r') : pn
endfunction

" if (%) in src, it replaces into path
function! s:ExpandWithSpecifiedPath(str, path)
	let lst=matchlist(a:str, '\([^(]*\)\((%[^)]*)\)\(.*\)')
	if len(lst) == 0
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

"
" run script file and the result shown in another window
"
function! s:RunScriptFile(cmd, fpath, buftitle, lsargs)
	let cmd=a:cmd
	let arg=len(a:lsargs) > 0 ? ' ' . join(a:lsargs, ' ') : ''
	let buftitle=a:buftitle
	let buftitle0=fnameescape(buftitle)
	let bufno = s:FindBufferWithTitle(buftitle)
	if bufno > 0
		execute bufno."bdelete!"
	endif

	if g:liteRunner_shows_quickfix_on_error
		execute ':cclose'
	endif

	"save splitbelow option to use below
	let save_sb=&splitbelow
	setlocal splitbelow
	"execute "5new " . buftitle0
	execute "" . g:liteRunner_windowheight_default . "new " . buftitle0
	set number
	setlocal bufhidden=delete "delete this buffer when hide
	setlocal noswapfile
	"change buftype to nofile to make no effect on chdir
	set buftype=nofile

	" try to get a custom errorformat
	let lsefm = s:GetCustomErrorFormatByProgname(s:GetProgname(cmd))
	if len(lsefm) > 0
		execute 'setlocal errorformat='.join(lsefm, ',')
	endif


	if has("win32")
		"TODO executable() check needed
		" in Windows cannot work /usr/bin/env
		let lcmd=split(cmd, ' ')
		if !executable(lcmd[0])
			if fnamemodify(lcmd[0], ':t') == 'env'
				let cmd=join(lcmd[1:], ' ') 
			endif
		endif
	endif

	" expand (%) symbols
	let excmd=s:ExpandWithSpecifiedPath(cmd, a:fpath)

	if cmd != excmd
		echo ":r!" . excmd . arg
		execute "r!" . excmd . arg
	else
		echo ":r!" . cmd . ' ' . a:fpath . arg
		execute "r!" . cmd . ' ' . a:fpath . arg
	endif

	"remove first empty line
	execute ':0d'
	setlocal nomod
	if has('localmap')
		" buffer local map <CR> jump back to previous window
		"noremap <buffer> <CR> :call MyJumpToPreviousWindow()<CR>
		noremap <buffer> <CR> :wincmd p<CR>
	endif
	
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
		wincmd p
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
			wincmd p
		endif
	endif
endfunction
"vim:ts=4:noex
