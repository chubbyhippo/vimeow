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

var state: string = ''
var saved: bool = false

def Esc(s: string): string
  return substitute(s, '[%|;&]', '\=printf("%%%d", char2nr(submatch(0)))', 'g')
enddef

def BindingRepr(b: dict<any>): string
  return join([
    'a=' .. Esc(get(b, 'action', '')),
    'k=' .. Esc(get(b, 'keys', '')),
    'c=' .. Esc(get(b, 'command', '')),
    'r=' .. string(get(b, 'recursive', false)),
  ], ',')
enddef

def MapRepr(m: dict<any>, ValueRepr: func(any): string): string
  var parts: list<string> = []
  for k in sort(keys(m))
    add(parts, Esc(k) .. '=>' .. ValueRepr(m[k]))
  endfor
  return join(parts, ';')
enddef

def Serialize(c: dict<any>): string
  var parts = [
    MapRepr(c.normal, BindingRepr),
    MapRepr(c.motion, BindingRepr),
    MapRepr(c.keypad, BindingRepr),
    MapRepr(c.keypadDesc, (v) => Esc(v)),
  ]
  var groups: list<string> = []
  for g in sort(keys(c.repeatGroups))
    add(groups, Esc(g) .. '=>' .. MapRepr(c.repeatGroups[g].map, BindingRepr))
  endfor
  add(parts, join(groups, '&'))
  add(parts, string(c.whichKey))
  add(parts, string(c.whichKeyDelayMs))
  return join(parts, '|')
enddef

export def SaveParsed(c: dict<any>)
  state = Serialize(c)
  saved = true
enddef

export def EqualTo(c: dict<any>): bool
  return saved && Serialize(c) == state
enddef

export def ResetForTest()
  state = ''
  saved = false
enddef
