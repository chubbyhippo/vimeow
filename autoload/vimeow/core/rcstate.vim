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

def Esc(text: string): string
  return substitute(text, '[%|;&]', '\=printf("%%%d", char2nr(submatch(0)))', 'g')
enddef

def BindingRepr(binding: dict<any>): string
  return join([
    'a=' .. Esc(get(binding, 'action', '')),
    'k=' .. Esc(get(binding, 'keys', '')),
    'c=' .. Esc(get(binding, 'command', '')),
    'r=' .. string(get(binding, 'recursive', false)),
  ], ',')
enddef

def MapRepr(entries: dict<any>, ValueRepr: func(any): string): string
  var parts: list<string> = []
  for key in sort(keys(entries))
    add(parts, Esc(key) .. '=>' .. ValueRepr(entries[key]))
  endfor
  return join(parts, ';')
enddef

def Serialize(config: dict<any>): string
  var parts = [
    MapRepr(config.normal, BindingRepr),
    MapRepr(config.motion, BindingRepr),
    MapRepr(config.keypad, BindingRepr),
    MapRepr(config.keypadDesc, (v) => Esc(v)),
  ]
  var groups: list<string> = []
  for group in sort(keys(config.repeatGroups))
    add(groups, Esc(group) .. '=>' .. MapRepr(config.repeatGroups[group].map, BindingRepr))
  endfor
  add(parts, join(groups, '&'))
  add(parts, string(config.whichKey))
  add(parts, string(config.whichKeyDelayMs))
  return join(parts, '|')
enddef

export def SaveParsed(config: dict<any>)
  state = Serialize(config)
  saved = true
enddef

export def EqualTo(config: dict<any>): bool
  return saved && Serialize(config) == state
enddef

export def ResetForTest()
  state = ''
  saved = false
enddef
