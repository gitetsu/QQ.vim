" Imports: {{{1
let s:B = QQ#buffers#import()
let s:R = QQ#regexp#import()

" Defaults: {{{1
let s:last_response = ''
let s:base_curl_query = g:QQ_curl_executable . " -si -w '\\r\\n".
      \ "\%{time_namelookup}\\r\\n".
      \ "\%{time_connect}\\r\\n".
      \ "\%{time_appconnect}\\r\\n".
      \ "\%{time_pretransfer}\\r\\n".
      \ "\%{time_redirect}\\r\\n".
      \ "\%{time_starttransfer}\\r\\n".
      \ "\%{time_total}'"

" Open: {{{1
function! QQ#response#open(...) abort
  "finds the RESPONSE buffer where ever it may be
  let l:buffer_created = 0
  if and(!bufexists(s:B.response), !bufexists(s:B.request))
    "neither request or response buffer exists
    sil! exe 'keepa bo 80vnew' s:B.response
    let l:buffer_created = 1
  elseif and(!bufexists(s:B.response), bufwinnr(s:B.request) != -1)
    "response buffer doesn't exist, request buffer exists and is in window
    call QQ#utils#focus_window_with_name(s:B.request)
    sil! exe 'badd' s:B.response
    sil! exe 'buf' bufnr(s:B.response) 
    sil! exe 'vert res 80'
    let l:buffer_created = 1
  elseif and(!bufexists(s:B.response), bufexists(s:B.request))
    "response buffer doesn't exist, request buffer exists but is not in window
    sil! exe 'keepa bo vert sb' s:B.request
    sil! exe 'vert res 80'
    sil! exe 'badd' s:B.response
    sil! exe 'buf' bufnr('') 
    let l:buffer_created = 1
  elseif and(bufwinnr(s:B.response) == -1, bufwinnr(s:B.request) != -1)
    "response buffer exists, request buffer exists and is in window
    call QQ#utils#focus_window_with_name(s:B.request)
    sil! exe 'buf' bufnr(s:B.response) 
  elseif bufwinnr(s:B.response) == -1
    "response buffer exists but is not in window
    sil! exe 'keepa bo vert sb' s:B.response
    sil! exe 'vert res 80'
  else 
    call QQ#utils#focus_window_with_name(s:B.response)
  endif
  call QQ#response#map_keys()
  call QQ#response#setup()
  if l:buffer_created
    let l:response = a:0 ? a:1 : s:last_response 
    let l:options = a:0 > 1 ? a:2 : []
    call QQ#response#populate(l:response, l:options)
  endif
endfunction

" Setup: {{{1

function! QQ#response#setup() abort
  set ft=QQ
  setl noswf nonu nobl nospell nocuc wfw
  setl fdc=0 fdl=99 tw=0 bt=nofile bh=hide
  if v:version > 702
    setl nornu noudf cc=0
  end
endfunction

" Populate: {{{1
function! QQ#response#split_response(response) abort
  let l:lines = split(a:response, "\\r\\n")
  if len(l:lines) > 6
    let l:times = lines[-7:]
    let l:time = {}
    let l:time.response = times[6]
    let l:time.name_lookup = times[0]
    let l:time.connect = times[1]
    let l:time.app_connect = times[2]
    let l:time.pre_transfer = times[3]
    let l:time.redirects = times[4]
    let l:time.start_transfer = times[5]
    let l:response = join(lines[:-8], "\r\n")
    let l:split_response = split(response, s:R.response_header)
    if len(split_response) > 1
      return [l:split_response[0], l:split_response[1], l:time]
    elseif len(l:split_response)
      return [l:split_response[0], '', l:time]
    else
      return ['', '', l:time]
    endif
  else
    return ['', '', '']
  endif
endfunction

function! QQ#response#format_time(time) abort
  let l:timeblock = "RESPONSE TIME: " . a:time.response . "\r\n"
  let l:timeblock .= "Name-Lookup: " . a:time.name_lookup. "\r\n"
  let l:timeblock .= "Connect: " . a:time.connect . "\r\n"
  let l:timeblock .= "App-Connect: " . a:time.app_connect . "\r\n"
  let l:timeblock .= "Pre-Transfer: " . a:time.pre_transfer . "\r\n"
  let l:timeblock .= "Redirects: " . a:time.redirects . "\r\n"
  let l:timeblock .= "Start-Transfer: " . a:time.start_transfer
  return l:timeblock
endfunction

function! QQ#response#populate(response, options) abort
  let [l:headers, l:body, l:time] = QQ#response#split_response(a:response)
  normal! gg"_dG
  if !len(l:headers)
    call append(0, '--NO RESPONSE--')
  else
    if index(a:options, 'pretty-print') != -1
      let l:tmpfn = tempname()
      call writefile(split(l:body, "\n"), l:tmpfn)
      let l:ppbody = system('python -m json.tool '.l:tmpfn)
      let l:body_split = split(l:ppbody, '\n')
    else
      let l:body_split = split(substitute(l:body, '\r\n', '\n', 'g'), '\n')
    endif
    let l:timeblock = QQ#response#format_time(l:time)
    let l:response = l:headers . "\r\n\r\n" . l:timeblock . "\r\n\r\n"
    call append(0, split(l:response, "\r\n") + l:body_split)
  endif
  normal! Gddgg
endfunction

" Mapping: {{{1
function! QQ#response#map_keys() abort
  map <buffer> q :call QQ#utils#close_window()<CR>
endfunction

" Misc: {{{1
" vim:fdm=marker
