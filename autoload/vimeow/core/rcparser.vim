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

def OrderedSet(entries: dict<any>, order: list<string>, key: string, value: any)
  if !has_key(entries, key)
    add(order, key)
  endif
  entries[key] = value
enddef

def CommentStart(line: string): number
  var depth = 0
  for i in range(len(line))
    var char = line[i]
    if char == '('
      depth += 1
    elseif char == ')'
      if depth > 0
        depth -= 1
      endif
    elseif char == '"' && depth == 0 && i > 0 && line[i - 1] =~ '\s'
      return i
    endif
  endfor
  return -1
enddef

def ParseKeys(spec: string, Err: func(string)): string
  var out: list<string> = []
  var i = 0
  var length = len(spec)
  while i < length
    var char = spec[i]
    if char == '<'
      var close = stridx(spec, '>', i)
      if close < 0
        add(out, char)
        i += 1
      else
        var token = tolower(strpart(spec, i + 1, close - i - 1))
        if token == 'space'
          add(out, ' ')
        elseif token == 'lt'
          add(out, '<')
        else
          Err('unsupported key token ' .. strpart(spec, i, close - i + 1)
              .. ' (only printable keys reach the meow engine)')
          return null_string
        endif
        i = close + 1
      endif
    else
      add(out, char)
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

def ParseSetColor(config: dict<any>, rest: string, Err: func(string))
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
  config[field] = color
enddef

def ParseSet(config: dict<any>, rest: string, Err: func(string))
  if rest == 'which-key'
    config.whichKey = true
  elseif rest == 'nowhich-key'
    config.whichKey = false
  elseif strpart(rest, 0, 10) == 'timeoutlen'
    var digits = ''
    if stridx(rest, '=') >= 0
      digits = matchstr(rest, '=\s*\zs-\?\d\+\ze\s*$')
    else
      digits = matchstr(rest, '^\S\+\s\+\zs-\?\d\+\ze\s*$')
    endif
    if digits != '' && str2nr(digits) >= 0
      config.whichKeyDelayMs = str2nr(digits)
    endif
  else
    ParseSetColor(config, rest, Err)
  endif
enddef

def ParseDescBody(config: dict<any>, body: string, Err: func(string))
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
  OrderedSet(config.keypadDesc, config.keypadDescOrder, seq, desc)
enddef

def ParseChordLine(config: dict<any>, cmd: string, rest: string, Err: func(string))
  var tokens = split(rest, '\s\+')
  if len(tokens) < 2
    Err(cmd .. ' needs a chord and a target')
    return
  endif
  var spelling = ''
  var consumed = 0
  for i in range(1, len(tokens) - 1)
    var candidate = join(tokens[0 : i - 1], ' ')
    if !empty(Chord.Parse(candidate))
      spelling = candidate
      consumed = i
      break
    endif
  endfor
  if spelling == ''
    Err('not a chord (needs Ctrl or Alt and one key): ' .. join(tokens, ' '))
    return
  endif
  var chord = Chord.Parse(spelling)
  var binding = ParseTarget(join(tokens[consumed : ], ' '), cmd == 'cmap', cmd .. ' ' .. rest, Err)
  if empty(binding)
    return
  endif
  OrderedSet(config.chords, config.chordOrder, Chord.Spelling(chord), binding)
enddef

def ParseResizeKey(config: dict<any>, cmd: string, rest: string, Err: func(string))
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
  OrderedSet(config.resizes, config.resizeOrder, key, binding)
enddef

def ParseMap(config: dict<any>, cmd: string, rest: string, Err: func(string))
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
      OrderedSet(config.keypad, config.keypadOrder, seq, binding)
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
      config.motion[keys] = binding
    else
      config.normal[keys] = binding
    endif
  endif
enddef

def ParseRepeat(config: dict<any>, rest: string, Err: func(string))
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
  if !has_key(config.repeatGroups, group)
    add(config.repeatOrder, group)
    config.repeatGroups[group] = {map: {}, order: []}
  endif
  var members = config.repeatGroups[group]
  OrderedSet(members.map, members.order, key, binding)
enddef

def ParseCommand(config: dict<any>, cmd: string, rest: string, Err: func(string))
  if get(ACCEPTED_AND_IGNORED_COMMANDS, cmd, false)
    return
  endif
  if get(MAP_COMMANDS, cmd, false)
    ParseMap(config, cmd, rest, Err)
  elseif cmd == 'cmap' || cmd == 'cnoremap'
    ParseChordLine(config, cmd, rest, Err)
  elseif cmd == 'resizemap' || cmd == 'resizenoremap'
    ParseResizeKey(config, cmd, rest, Err)
  elseif cmd == 'set'
    ParseSet(config, rest, Err)
  elseif cmd == 'desc'
    ParseDescBody(config, rest, Err)
  elseif cmd == 'repeat'
    ParseRepeat(config, rest, Err)
  else
    Err("unknown command '" .. cmd .. "'")
  endif
enddef

def ParseLine(config: dict<any>, raw: string, Err: func(string))
  var line = raw
  if line == '' || line[0] == '"' || line[0] == '#'
    return
  endif
  var whichKeyDesc = matchstr(line, WHICH_KEY_DESC_PATTERN)
  if whichKeyDesc != ''
    ParseDescBody(config, whichKeyDesc, Err)
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
  ParseCommand(config, cmd, trim(strpart(line, len(cmd))), Err)
enddef

export def Parse(lines: list<string>): dict<any>
  var config = NewConfig()
  var i = 0
  for raw in lines
    i += 1
    var lineNo = i
    var Err = (msg: string) => {
      add(config.errors, 'line ' .. lineNo .. ': ' .. msg)
    }
    ParseLine(config, trim(raw), Err)
  endfor
  return config
enddef
