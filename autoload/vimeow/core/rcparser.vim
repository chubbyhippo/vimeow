vim9script
# Copyright (C) 2026 Chubby Hippo
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: GPL-3.0-or-later

import autoload 'vimeow/core/registry.vim' as Registry
import autoload 'vimeow/core/chord.vim' as Chord

const COLOR_SET_KEYS = {
  'overlay-color': 'overlayColor',
  'overlay-text-color': 'overlayTextColor',
  'expand-hint-color': 'expandHintColor',
  'grab-color': 'grabColor',
}

const ACCEPTED_AND_IGNORED_COMMANDS = {let: true}

const MAP_COMMANDS = {
  map: true, noremap: true,
  nmap: true, nnoremap: true,
  mmap: true, mnoremap: true,
}

const WHICH_KEY_DESC_PATTERN = '^let\s\+g:WhichKeyDesc[0-9A-Za-z_]*\s*=\s*"\zs.\+\ze"$'

export def NewConfig(): dict<any>
  return {
    normal: {},
    motion: {},
    keypad: {},
    keypadOrder: [],
    keypadDesc: {},
    keypadDescOrder: [],
    chords: {},
    chordOrder: [],
    resizes: {},
    resizeOrder: [],
    repeatGroups: {},
    repeatOrder: [],
    whichKey: null,
    whichKeyDelayMs: -1,
    overlayColor: '',
    overlayTextColor: '',
    expandHintColor: '',
    grabColor: '',
    errors: [],
  }
enddef

def OrderedSet(m: dict<any>, order: list<string>, key: string, value: any)
  if !has_key(m, key)
    add(order, key)
  endif
  m[key] = value
enddef

def CommentStart(line: string): number
  var depth = 0
  for i in range(len(line))
    var ch = line[i]
    if ch == '('
      depth += 1
    elseif ch == ')'
      if depth > 0
        depth -= 1
      endif
    elseif ch == '"' && depth == 0 && i > 0 && line[i - 1] =~ '\s'
      return i
    endif
  endfor
  return -1
enddef

def ParseKeys(s: string, Err: func(string)): string
  var out: list<string> = []
  var i = 0
  var n = len(s)
  while i < n
    var ch = s[i]
    if ch == '<'
      var close = stridx(s, '>', i)
      if close < 0
        add(out, ch)
        i += 1
      else
        var token = tolower(strpart(s, i + 1, close - i - 1))
        if token == 'space'
          add(out, ' ')
        elseif token == 'lt'
          add(out, '<')
        else
          Err('unsupported key token ' .. strpart(s, i, close - i + 1)
              .. ' (only printable keys reach the meow engine)')
          return null_string
        endif
        i = close + 1
      endif
    else
      add(out, ch)
      i += 1
    endif
  endwhile
  return join(out, '')
enddef

def ParseTarget(rhs: string, recursive: bool, errContext: string, Err: func(string)): dict<any>
  var action = matchstr(rhs, '^<[Aa][Cc][Tt][Ii][Oo][Nn]>(\zs.\+\ze)$')
  if action != ''
    return {action: action, recursive: recursive}
  endif
  if Registry.Has(rhs)
    return {command: rhs, recursive: recursive}
  endif
  if strpart(rhs, 0, 5) == 'meow-'
    Err("unknown meow command '" .. rhs .. "'")
    return {}
  endif
  var keys = ParseKeys(substitute(rhs, '\s\+', '', 'g'), Err)
  if keys == null_string
    return {}
  endif
  if keys == ''
    Err("empty target in '" .. errContext .. "'")
    return {}
  endif
  return {keys: keys, recursive: recursive}
enddef

def ParseHexColor(text: string): string
  var hex = substitute(text, '^#', '', '')
  if hex !~ '^\x\{6}$'
    return ''
  endif
  return '#' .. tolower(hex)
enddef

def ParseSetColor(c: dict<any>, rest: string, Err: func(string))
  var key = trim(matchstr(rest, '^[^=]*'))
  var field = get(COLOR_SET_KEYS, key, '')
  if field == ''
    return
  endif
  var value = trim(substitute(rest, '^[^=]*=\?', '', ''))
  var color = ParseHexColor(value)
  if color == ''
    Err('set ' .. key .. ": invalid color '" .. value .. "' (expected #RRGGBB)")
    return
  endif
  c[field] = color
enddef

def ParseSet(c: dict<any>, rest: string, Err: func(string))
  if rest == 'which-key'
    c.whichKey = true
  elseif rest == 'nowhich-key'
    c.whichKey = false
  elseif strpart(rest, 0, 10) == 'timeoutlen'
    var digits = ''
    if stridx(rest, '=') >= 0
      digits = matchstr(rest, '=\s*\zs-\?\d\+\ze\s*$')
    else
      digits = matchstr(rest, '^\S\+\s\+\zs-\?\d\+\ze\s*$')
    endif
    if digits != '' && str2nr(digits) >= 0
      c.whichKeyDelayMs = str2nr(digits)
    endif
  else
    ParseSetColor(c, rest, Err)
  endif
enddef

def ParseDescBody(c: dict<any>, body: string, Err: func(string))
  if strpart(body, 0, 8) != '<leader>'
    Err('descriptions must start with <leader>: ' .. body)
    return
  endif
  var after = strpart(body, 8)
  var seqToken = matchstr(after, '^\S*')
  var desc = trim(strpart(after, len(seqToken)))
  var seq = ParseKeys(seqToken, Err)
  if seq == null_string
    return
  endif
  if seq == ''
    Err('empty key sequence in description: ' .. body)
    return
  endif
  OrderedSet(c.keypadDesc, c.keypadDescOrder, seq, desc)
enddef

def ParseChordLine(c: dict<any>, cmd: string, rest: string, Err: func(string))
  var split = match(rest, '\s\+\S*$')
  if split <= 0
    Err(cmd .. ' needs a chord and a target')
    return
  endif
  var spelling = trim(strpart(rest, 0, split))
  var chord = Chord.Parse(spelling)
  if empty(chord)
    Err('not a chord (needs Ctrl or Alt and one key): ' .. spelling)
    return
  endif
  var binding = ParseTarget(trim(strpart(rest, split)), cmd == 'cmap', cmd .. ' ' .. rest, Err)
  if empty(binding)
    return
  endif
  OrderedSet(c.chords, c.chordOrder, Chord.Spelling(chord), binding)
enddef

def ParseResizeKey(c: dict<any>, cmd: string, rest: string, Err: func(string))
  var lhs = matchstr(rest, '^\S\+')
  var rhs = trim(strpart(rest, len(lhs)))
  if lhs == '' || rhs == ''
    Err(cmd .. ' needs a key and a target')
    return
  endif
  var key = ParseKeys(lhs, Err)
  if key == null_string
    return
  endif
  if len(key) != 1
    Err('resize key must be a single printable key: ' .. lhs)
    return
  endif
  var binding = ParseTarget(rhs, cmd == 'resizemap', cmd .. ' ' .. rest, Err)
  if empty(binding)
    return
  endif
  OrderedSet(c.resizes, c.resizeOrder, key, binding)
enddef

def ParseMap(c: dict<any>, cmd: string, rest: string, Err: func(string))
  var lhs = matchstr(rest, '^\S\+')
  var rhs = trim(strpart(rest, len(lhs)))
  if lhs == '' || rhs == ''
    Err(cmd .. ' needs a key and a target')
    return
  endif
  var recursive = cmd == 'map' || cmd == 'nmap' || cmd == 'mmap'
  var motion = cmd == 'mmap' || cmd == 'mnoremap'

  var binding = ParseTarget(rhs, recursive, cmd .. ' ' .. rest, Err)
  if empty(binding)
    return
  endif

  if strpart(lhs, 0, 8) == '<leader>'
    if motion
      Err(cmd .. ' cannot define keypad entries; use map <leader>...')
      return
    endif
    var seq = ParseKeys(strpart(lhs, 8), Err)
    if seq == null_string
      return
    endif
    if seq == ''
      Err('<leader> alone cannot be mapped')
    elseif stridx('0123456789?/', seq[0]) >= 0
      Err('keypad ' .. seq[0] .. ' is reserved (digit argument / cheatsheet / describe)')
    else
      OrderedSet(c.keypad, c.keypadOrder, seq, binding)
    endif
    return
  endif

  var keys = ParseKeys(lhs, Err)
  if keys == null_string
    return
  endif
  if len(keys) != 1
    Err((motion ? 'motion' : 'normal') .. '-mode key must be a single printable key: ' .. lhs)
  elseif keys == ' '
    Err('SPC is the keypad key and cannot be remapped')
  else
    if motion
      c.motion[keys] = binding
    else
      c.normal[keys] = binding
    endif
  endif
enddef

def ParseRepeat(c: dict<any>, rest: string, Err: func(string))
  var parts = matchlist(rest, '^\(\S\+\)\s\+\(\S\+\)\s\+\(.*\)$')
  if empty(parts)
    Err('repeat needs a group, a member key and a target')
    return
  endif
  var group = parts[1]
  var keyToken = parts[2]
  var rhs = trim(parts[3])
  var key = ParseKeys(keyToken, Err)
  if key == null_string
    return
  endif
  if len(key) != 1
    Err('repeat member key must be a single printable key: ' .. keyToken)
    return
  endif
  if key == ' '
    Err('SPC is the keypad key and cannot be a repeat member')
    return
  endif
  var binding = ParseTarget(rhs, true, 'repeat ' .. rest, Err)
  if empty(binding)
    return
  endif
  if !has_key(c.repeatGroups, group)
    add(c.repeatOrder, group)
    c.repeatGroups[group] = {map: {}, order: []}
  endif
  var members = c.repeatGroups[group]
  OrderedSet(members.map, members.order, key, binding)
enddef

def ParseCommand(c: dict<any>, cmd: string, rest: string, Err: func(string))
  if get(ACCEPTED_AND_IGNORED_COMMANDS, cmd, false)
    return
  endif
  if get(MAP_COMMANDS, cmd, false)
    ParseMap(c, cmd, rest, Err)
  elseif cmd == 'cmap' || cmd == 'cnoremap'
    ParseChordLine(c, cmd, rest, Err)
  elseif cmd == 'resizemap' || cmd == 'resizenoremap'
    ParseResizeKey(c, cmd, rest, Err)
  elseif cmd == 'set'
    ParseSet(c, rest, Err)
  elseif cmd == 'desc'
    ParseDescBody(c, rest, Err)
  elseif cmd == 'repeat'
    ParseRepeat(c, rest, Err)
  else
    Err("unknown command '" .. cmd .. "'")
  endif
enddef

def ParseLine(c: dict<any>, raw: string, Err: func(string))
  var line = raw
  if line == '' || line[0] == '"' || line[0] == '#'
    return
  endif
  var whichKeyDesc = matchstr(line, WHICH_KEY_DESC_PATTERN)
  if whichKeyDesc != ''
    ParseDescBody(c, whichKeyDesc, Err)
    return
  endif
  var cut = CommentStart(line)
  if cut >= 0
    line = trim(strpart(line, 0, cut))
  endif
  if line == ''
    return
  endif
  var cmd = matchstr(line, '^\S\+')
  ParseCommand(c, cmd, trim(strpart(line, len(cmd))), Err)
enddef

export def Parse(lines: list<string>): dict<any>
  var c = NewConfig()
  var i = 0
  for raw in lines
    i += 1
    var lineNo = i
    var Err = (msg: string) => {
      add(c.errors, 'line ' .. lineNo .. ': ' .. msg)
    }
    ParseLine(c, trim(raw), Err)
  endfor
  return c
enddef
