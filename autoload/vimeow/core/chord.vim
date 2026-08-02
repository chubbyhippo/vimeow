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

const PLAIN_KEYS = {
  SPC: ' ', SPACE: ' ', TAB: "\t",
  COMMA: ',', PERIOD: '.', SLASH: '/', SEMICOLON: ';', QUOTE: "'",
  OPEN_BRACKET: '[', CLOSE_BRACKET: ']', BACK_SLASH: '\',
  MINUS: '-', EQUALS: '=', BACK_QUOTE: '`',
  BSLASH: '\', BAR: '|', LT: '<',
}

const SHIFTED_KEYS = {
  COMMA: '<', PERIOD: '>', SLASH: '?', SEMICOLON: ':', QUOTE: '"',
  OPEN_BRACKET: '{', CLOSE_BRACKET: '}', BACK_SLASH: '|',
  MINUS: '_', EQUALS: '+', BACK_QUOTE: '~',
  '1': '!', '2': '@', '3': '#', '4': '$', '5': '%',
  '6': '^', '7': '&', '8': '*', '9': '(', '0': ')',
}

const HOST_MODIFIERS = {
  control: 'ctrl', ctrl: 'ctrl',
  alt: 'alt', meta: 'alt',
  shift: 'shift',
}

const PREFIX_MODIFIERS = {C: 'ctrl', M: 'alt', A: 'alt', S: 'shift'}

def IsLowerLetter(char: string): bool
  return char =~ '^\l$'
enddef

def IsUpperLetter(char: string): bool
  return char =~ '^\u$'
enddef

export def Named(token: string, shift: bool): string
  var name = toupper(token)
  if shift && has_key(SHIFTED_KEYS, name)
    return SHIFTED_KEYS[name]
  endif
  if has_key(PLAIN_KEYS, name)
    return PLAIN_KEYS[name]
  endif
  return len(token) == 1 ? token : ''
enddef

def ParseHostSpelling(text: string): dict<any>
  var tokens = split(text, '\s\+')
  var mods = {ctrl: false, alt: false, shift: false}
  for i in range(len(tokens) - 1)
    var mod = get(HOST_MODIFIERS, tolower(tokens[i]), '')
    if mod == ''
      return {}
    endif
    mods[mod] = true
  endfor
  var named = Named(tokens[-1], mods.shift)
  if named == '' || !(mods.ctrl || mods.alt)
    return {}
  endif
  return {
    ctrl: mods.ctrl,
    alt: mods.alt,
    shift: mods.shift && IsLowerLetter(tolower(named)),
    key: tolower(named),
  }
enddef

def ParsePrefixSpelling(text: string): dict<any>
  var rest = text
  var mods = {ctrl: false, alt: false, shift: false}
  while len(rest) > 2 && rest[1] == '-'
    var mod = get(PREFIX_MODIFIERS, toupper(rest[0]), '')
    if mod == ''
      return {}
    endif
    mods[mod] = true
    rest = strpart(rest, 2)
  endwhile
  var named = Named(rest, mods.shift)
  if named == '' || !(mods.ctrl || mods.alt)
    return {}
  endif
  if IsUpperLetter(named)
    return {ctrl: mods.ctrl, alt: mods.alt, shift: true, key: tolower(named)}
  endif
  return {ctrl: mods.ctrl, alt: mods.alt, shift: mods.shift, key: named}
enddef

export def Parse(text: string): dict<any>
  var rest = trim(text)
  if rest == ''
    return {}
  endif
  if len(rest) > 2 && rest[0] == '<' && rest[len(rest) - 1] == '>'
    rest = strpart(rest, 1, len(rest) - 2)
  endif
  if rest =~ '\s'
    return ParseHostSpelling(rest)
  endif
  return ParsePrefixSpelling(rest)
enddef

export def Spelling(chord: dict<any>): string
  var prefix = (chord.ctrl ? 'C-' : '') .. (chord.alt ? 'M-' : '') .. (chord.shift ? 'S-' : '')
  return prefix .. chord.key
enddef

export def KeyOf(text: string): string
  var chord = Parse(text)
  return empty(chord) ? '' : Spelling(chord)
enddef
