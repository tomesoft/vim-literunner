" File: plugin/literunner.vim
" Version: 0.2
"
" liteRunner plugin
"
" Supports edit-run-edit cycle of your scripting
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

" ConqueTerm Command
"if !exists("g:liteRunner_ConqueTerm_command") && exists(":ConqueTerm")
    "let g:liteRunner_ConqueTerm_command='ConqueTermSplit'
"endif

" flag reexec ConqueTerm always or not
if !exists("g:liteRunner_ConqueTerm_reexec_always")
    let g:liteRunner_ConqueTerm_reexec_always=0
endif

" 0=never passing, 1=selection only, 2=entire of content
if !exists("g:liteRunner_ConqueTerm_contents_passing_mode")
    let g:liteRunner_ConqueTerm_contents_passing_mode=1
endif

"
" dictionary of filetypes and commands
" key=filetype : value=[command-str, command-str-of-interactive]
" typically, editing file path is concatenated after command with whitespace.
" if (%) in command string, it replaced with editing file path.
" e.g. script -i=(%) --dir=(%:h)
if !exists("g:liteRunner_ftyps_cmds_dict")
    let g:liteRunner_ftyps_cmds_dict={
        \"scheme": ["/usr/bin/env gosh", "/usr/bin/env gosh -i"],
        \"perl": ["/usr/bin/env perl"],
        \"python": ["/usr/bin/env python"],
        \"ruby": ["/usr/bin/env ruby", "/usr/bin/env irb"],
        \"lua": ["/usr/bin/env lua"],
        \"php": ["/usr/bin/env php"],
        \"sh": ["/usr/bin/env sh"],
        \"csh": ["/usr/bin/env csh"],
        \}

    if has('unix')
    elseif has('win32')
        " TODO: for win32 settings here
        let g:liteRunner_ftyps_cmds_dict={
            \"scheme": ["gosh", "gosh -i"],
            \"perl": ["perl"],
            \"python": ["python"],
            \"ruby": ["ruby", "irb"],
            \"lua": ["lua"],
            \"php": ["php"],
            \}
    endif
    " appendix : experimental
    if has('mac')
        let g:liteRunner_ftyps_cmds_dict["html"] = ["open"]
    endif
    "let g:liteRunner_ftyps_cmds_dict["scheme"] = ["mit-scheme --load (%)"]
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
