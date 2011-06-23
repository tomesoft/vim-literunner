" File: plugin/liteRunner.vim
" Version: 0.5
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

" command when buffer split
if !exists("g:liteRunner_buffer_split_command")
    let g:liteRunner_buffer_split_command="belowright split"
endif

" output window height default
if !exists("g:liteRunner_windowheight_default")
    let g:liteRunner_windowheight_default=5
endif

" output window height max
if !exists("g:liteRunner_windowheight_max")
    let g:liteRunner_windowheight_max=10
endif

" a flag either use ConqueTerm or not for interactive mode
if !exists("g:liteRunner_uses_ConqueTerm")
    let g:liteRunner_uses_ConqueTerm = 0
endif

" a flag either use VimShell or not for interactive mode
if !exists("g:liteRunner_uses_VimShell")
    let g:liteRunner_uses_VimShell = 0
endif

" ConqueTerm Command
"if !exists("g:liteRunner_ConqueTerm_command")
"    let g:liteRunner_ConqueTerm_command='ConqueTermSplit'
"endif

" flag renew interactive buffer everytime or not
if !exists("g:liteRunner_interactive_buffer_renew_everytime")
    let g:liteRunner_interactive_buffer_renew_everytime=0
endif

" VimShell Command
if !exists("g:liteRunner_VimShell_command")
    let g:liteRunner_VimShell_command='VimShellInteractive'
endif

" 0=never passing, 1=selection only, 2=entire of content
if !exists("g:liteRunner_interactive_content_pass_mode")
    let g:liteRunner_interactive_content_pass_mode=1
endif

"
" dictionary of filetypes and commands
" key=filetype : value=[command-str, command-str-of-interactive]
" typically, editing file path is concatenated after command with whitespace.
" if (%) in command string, it replaced with editing file path.
" e.g. script -i=(%) --dir=(%:h)
if !exists("g:liteRunner_ftyps_cmds_dict")
    let s:ENVPROG='/usr/bin/env'
    if !executable(s:ENVPROG)
        " search env in path
        let s:ENVPROG = glob('`which env`')
    endif
    let s:ENV=''
    if !empty(s:ENVPROG)
        let s:ENV = s:ENVPROG.' '
    endif
    unlet s:ENVPROG
    "TODO: maintain list
    let g:liteRunner_ftyps_cmds_dict={
        \'awk'      : [s:ENV.'awk -f'],
        \'lua'      : [s:ENV.'lua'],
        \'perl'     : [s:ENV.'perl'],
        \'php'      : [s:ENV.'php'],
        \'python'   : [s:ENV.'python'],
        \'ruby'     : [s:ENV.'ruby', s:ENV.'irb'],
        \'scheme'   : [s:ENV.'gosh', s:ENV.'gosh -i'],
        \'sed'      : [s:ENV.'sed -f'],
        \'sh'       : [s:ENV.'sh'],
        \'csh'      : [s:ENV.'csh'],
        \'tcsh'     : [s:ENV.'tcsh'],
        \'zsh'      : [s:ENV.'zsh'],
        \}

    if has('unix')
    elseif has('win32')
    endif
    " appendix : experimental
    if has('mac')
        let g:liteRunner_ftyps_cmds_dict['html'] = ['open']
    endif
    "let g:liteRunner_ftyps_cmds_dict['scheme'] = ['mit-scheme --load (%)']
    unlet s:ENV
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
        :nnoremap <Leader>i :LRRunScriptInteractively<CR>
        :vnoremap <Leader>i :LRRunScriptInteractivelyV<CR>
    endif
endif

"if !hasmapto('LRRunScriptInteractivelyWithEntireOfContent')
"    if mapcheck('<Leader>I') == ''
"        :noremap <Leader>I :LRRunScriptInteractivelyWithEntireOfContent<CR>
"    endif
"endif

if !hasmapto('LRRunRepl')
    if mapcheck('<Leader>I') == ''
        :nnoremap <Leader>I :<C-\>e("LRRunRepl " . liteRunner#ExpandRepl())<CR>
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
command! -nargs=* -range=% LRRunRepl :call liteRunner#RunRepl(<line1>, <line2>, <q-args>)
command! -nargs=0 -range=% LRRunScriptInteractively :call liteRunner#RunScriptInteractively(<line1>, <line2>, 0)
" for Visual mode
command! -nargs=0 -range LRRunScriptInteractivelyV :call liteRunner#RunScriptInteractively(<line1>, <line2>, 1)
command! -nargs=0 -range=% LRRunScriptInteractivelyWithEntireOfContent :call liteRunner#RunScriptInteractivelyWithEntireOfContent()


" vim:ts=8:sts=4:sw=4:et
