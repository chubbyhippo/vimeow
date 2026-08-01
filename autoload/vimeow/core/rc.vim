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

import autoload 'vimeow/core/rcparser.vim' as RcParser
import autoload 'vimeow/core/rcstate.vim' as RcState

export const FILE_NAME = '.vimeowrc'

const DEFAULT_WHICH_KEY_DELAY_MS = 250
const DEFAULT_OVERLAY_COLOR = '#2ecc71'
const DEFAULT_OVERLAY_TEXT_COLOR = '#ffffff'
const DEFAULT_EXPAND_HINT_COLOR = '#2b5db2'
const DEFAULT_GRAB_COLOR = ''

var userConfig: dict<any> = RcParser.NewConfig()
var defaultConfig: dict<any> = RcParser.NewConfig()

export def NewConfig(): dict<any>
  return RcParser.NewConfig()
enddef

export def Parse(lines: list<string>): dict<any>
  return RcParser.Parse(lines)
enddef

export def InitDefaults(lines: list<string>): dict<any>
  defaultConfig = RcParser.Parse(lines)
  return defaultConfig
enddef

export def SetUserLines(lines: list<string>): dict<any>
  userConfig = RcParser.Parse(lines)
  RcState.SaveParsed(userConfig)
  return userConfig
enddef

export def SetForTest(c: dict<any>)
  userConfig = c
  RcState.ResetForTest()
enddef

export def Cfg(): dict<any>
  return userConfig
enddef

export def Defaults(): dict<any>
  return defaultConfig
enddef

def MergedOrdered(
    defMap: dict<any>, defOrder: list<string>,
    userMap: dict<any>, userOrder: list<string>): list<any>
  var m: dict<any> = {}
  var order: list<string> = []
  for k in defOrder
    if !has_key(m, k)
      add(order, k)
    endif
    m[k] = defMap[k]
  endfor
  for k in userOrder
    if !has_key(m, k)
      add(order, k)
    endif
    m[k] = userMap[k]
  endfor
  return [m, order]
enddef

export def Keypad(): list<any>
  return MergedOrdered(defaultConfig.keypad, defaultConfig.keypadOrder,
                       userConfig.keypad, userConfig.keypadOrder)
enddef

export def KeypadDescs(): list<any>
  return MergedOrdered(defaultConfig.keypadDesc, defaultConfig.keypadDescOrder,
                       userConfig.keypadDesc, userConfig.keypadDescOrder)
enddef

def PrunedIgnores(pair: list<any>): list<any>
  var m = pair[0]
  var order = pair[1]
  var kept: list<string> = []
  for key in order
    if get(m[key], 'command', '') == 'ignore'
      remove(m, key)
    else
      add(kept, key)
    endif
  endfor
  return [m, kept]
enddef

export def ChordBindings(): dict<any>
  return PrunedIgnores(MergedOrdered(
    defaultConfig.chords, defaultConfig.chordOrder,
    userConfig.chords, userConfig.chordOrder))[0]
enddef

export def ChordOrder(): list<string>
  return PrunedIgnores(MergedOrdered(
    defaultConfig.chords, defaultConfig.chordOrder,
    userConfig.chords, userConfig.chordOrder))[1]
enddef

export def ResizeBindings(): dict<any>
  return PrunedIgnores(MergedOrdered(
    defaultConfig.resizes, defaultConfig.resizeOrder,
    userConfig.resizes, userConfig.resizeOrder))[0]
enddef

export def ResizeOrder(): list<string>
  return PrunedIgnores(MergedOrdered(
    defaultConfig.resizes, defaultConfig.resizeOrder,
    userConfig.resizes, userConfig.resizeOrder))[1]
enddef

export def RepeatGroups(): list<any>
  var merged: dict<any> = {}
  var order: list<string> = []
  for group in defaultConfig.repeatOrder
    var src = defaultConfig.repeatGroups[group]
    var members = {map: {}, order: []}
    for k in src.order
      members.map[k] = src.map[k]
      add(members.order, k)
    endfor
    merged[group] = members
    add(order, group)
  endfor
  for group in userConfig.repeatOrder
    var src = userConfig.repeatGroups[group]
    if !has_key(merged, group)
      merged[group] = {map: {}, order: []}
      add(order, group)
    endif
    var members = merged[group]
    for k in src.order
      if !has_key(members.map, k)
        add(members.order, k)
      endif
      members.map[k] = src.map[k]
    endfor
  endfor
  var prunedOrder: list<string> = []
  for group in order
    var members = merged[group]
    var keptOrder: list<string> = []
    for k in members.order
      if get(members.map[k], 'command', '') == 'ignore'
        remove(members.map, k)
      else
        add(keptOrder, k)
      endif
    endfor
    members.order = keptOrder
    if empty(keptOrder)
      remove(merged, group)
    else
      add(prunedOrder, group)
    endif
  endfor
  return [merged, prunedOrder]
enddef

def SameBinding(a: dict<any>, b: dict<any>): bool
  return get(a, 'action', '') == get(b, 'action', '')
      && get(a, 'command', '') == get(b, 'command', '')
      && get(a, 'keys', '') == get(b, 'keys', '')
enddef

export def RepeatMapFor(binding: dict<any>): dict<any>
  var pair = RepeatGroups()
  var groups = pair[0]
  for group in pair[1]
    var members = groups[group]
    for k in members.order
      if SameBinding(members.map[k], binding)
        return members
      endif
    endfor
  endfor
  return {}
enddef

export def WhichKeyEnabled(): bool
  if userConfig.whichKey != null
    return userConfig.whichKey
  endif
  if defaultConfig.whichKey != null
    return defaultConfig.whichKey
  endif
  return true
enddef

export def WhichKeyDelayMs(): number
  if userConfig.whichKeyDelayMs >= 0
    return userConfig.whichKeyDelayMs
  endif
  if defaultConfig.whichKeyDelayMs >= 0
    return defaultConfig.whichKeyDelayMs
  endif
  return DEFAULT_WHICH_KEY_DELAY_MS
enddef

def ResolveColor(field: string, fallback: string): string
  if userConfig[field] != ''
    return userConfig[field]
  endif
  if defaultConfig[field] != ''
    return defaultConfig[field]
  endif
  return fallback
enddef

export def OverlayColor(): string
  return ResolveColor('overlayColor', DEFAULT_OVERLAY_COLOR)
enddef

export def OverlayTextColor(): string
  return ResolveColor('overlayTextColor', DEFAULT_OVERLAY_TEXT_COLOR)
enddef

export def ExpandHintColor(): string
  return ResolveColor('expandHintColor', DEFAULT_EXPAND_HINT_COLOR)
enddef

export def GrabColor(): string
  return ResolveColor('grabColor', DEFAULT_GRAB_COLOR)
enddef
