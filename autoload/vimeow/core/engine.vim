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

import autoload 'vimeow/core/state.vim' as St
import autoload 'vimeow/core/port.vim' as P
import autoload 'vimeow/core/registry.vim' as Registry
import autoload 'vimeow/core/rc.vim' as Rc
import autoload 'vimeow/core/motions.vim' as Motions
import autoload 'vimeow/core/selections.vim' as Sel
import autoload 'vimeow/core/structures.vim' as Structures
import autoload 'vimeow/core/keypad.vim' as Keypad
import autoload 'vimeow/core/avy.vim' as Avy

const MAX_REPLAY_DEPTH = 8

export var repeatMap: dict<any> = {}

export def ClearRepeat()
  repeatMap = {}
enddef

export def EnterKeypad(ctx: P.Ctx)
  if ctx.state.mode == St.KEYPAD
    return
  endif
  ctx.state.keypadPreviousState = ctx.state.mode
  ctx.SetMode(St.KEYPAD)
  ctx.ui.ScheduleWhichKey('keypad', '')
enddef

export def RunEmacsMotion(ctx: P.Ctx, command: string)
  if Registry.Has(command)
    Registry.COMMANDS[command](ctx)
  endif
  ctx.ui.Refresh(ctx.state)
enddef

def Resolve(ctx: P.Ctx, char: string, motion: bool): dict<any>
  if char == ' '
    return {command: 'meow-keypad', recursive: true}
  endif
  if ctx.state.noremapDepth == 0
    var cfg = Rc.Cfg()
    var user = motion ? get(cfg.motion, char, {}) : get(cfg.normal, char, {})
    if !empty(user)
      return user
    endif
  endif
  var defaults = Rc.Defaults()
  return motion ? get(defaults.motion, char, {}) : get(defaults.normal, char, {})
enddef

def ResolvePending(ctx: P.Ctx, pending: string, char: string)
  if pending == St.PENDING_FIND
    Motions.FindTill(ctx, char, false)
  elseif pending == St.PENDING_TILL
    Motions.FindTill(ctx, char, true)
  else
    Structures.ThingSelect(ctx, pending, char)
  endif
enddef

def StartsMultiKeyInput(state: St.MeowState, cmd: string): bool
  return state.pending != ''
      || (state.pendingCount != 0 && cmd != '' && strpart(cmd, 0, 12) == 'meow-expand-')
      || (state.negative && cmd == 'meow-negative-argument')
      || cmd == 'meow-keypad'
enddef

export def HandleChar(ctx: P.Ctx, char: string): bool
  var state = ctx.state
  if state.mode == St.INSERT
    return false
  endif
  if state.mode == St.KEYPAD
    Keypad.Key(ctx, char)
    state.lastCommand = 'keypad'
    ctx.ui.Refresh(state)
    return true
  endif
  if state.HasAvy()
    Avy.Key(ctx, char)
    state.lastCommand = 'avy'
    ctx.ui.Refresh(state)
    return true
  endif

  ctx.ui.HideWhichKey()
  ctx.ui.ClearExpandHints()

  var pend = state.pending
  var repeatBinding: dict<any> = {}
  if pend == '' && !empty(repeatMap)
    repeatBinding = get(repeatMap.map, char, {})
  endif
  if pend == '' && empty(repeatBinding)
    repeatMap = {}
  endif
  var motionish = state.mode == St.MOTION
  var binding: dict<any> = {}
  if pend == ''
    binding = empty(repeatBinding) ? Resolve(ctx, char, motionish) : repeatBinding
  endif
  var cmd = get(binding, 'command', '')

  if !state.replaying && cmd != 'repeat'
    if pend == '' && state.pendingCount == 0 && !state.negative
      state.unit = []
    endif
    add(state.unit, char)
  endif

  if pend != ''
    state.pending = ''
    ResolvePending(ctx, pend, char)
    state.lastCommand = 'pending'
  elseif !empty(binding)
    RunBinding(ctx, binding)
    var fallback = cmd != '' ? cmd : get(binding, 'action', '')
    state.lastCommand = fallback != '' ? fallback : state.lastCommand
  else
    state.lastCommand = ''
  endif

  if !state.replaying && cmd != 'repeat' && !StartsMultiKeyInput(state, cmd)
    state.lastKeys = copy(state.unit)
  endif

  ctx.ui.Refresh(state)
  return true
enddef

export def RepeatLast(ctx: P.Ctx)
  var state = ctx.state
  var keys = state.lastKeys
  if empty(keys)
    return
  endif
  state.replaying = true
  try
    for key in keys
      HandleChar(ctx, key)
    endfor
  finally
    state.replaying = false
  endtry
enddef

def Dispatch(ctx: P.Ctx, binding: dict<any>)
  var state = ctx.state
  var command = get(binding, 'command', '')
  if command != ''
    if Registry.Has(command)
      Registry.COMMANDS[command](ctx)
    else
      ctx.ui.Hint('Unknown meow command: ' .. command)
    endif
    return
  endif
  var action = get(binding, 'action', '')
  if action != ''
    try
      ctx.ui.RunCommand(action)
    catch
      ctx.ui.Hint('Unknown command: ' .. action)
    endtry
    return
  endif
  var keys = get(binding, 'keys', '')
  if keys == ''
    return
  endif
  if state.replayDepth >= MAX_REPLAY_DEPTH
    ctx.ui.Hint('vimeow: mapping recursion is too deep')
    return
  endif
  var savedReplaying = state.replaying
  var recursive = get(binding, 'recursive', false)
  state.replaying = true
  state.replayDepth += 1
  if !recursive
    state.noremapDepth += 1
  endif
  try
    for i in range(len(keys))
      HandleChar(ctx, keys[i])
    endfor
  finally
    if !recursive
      state.noremapDepth -= 1
    endif
    state.replayDepth -= 1
    state.replaying = savedReplaying
  endtry
enddef

export def RunBinding(ctx: P.Ctx, binding: dict<any>)
  Dispatch(ctx, binding)
  var group = Rc.RepeatMapFor(binding)
  if empty(group)
    return
  endif
  if empty(repeatMap)
    ctx.ui.Hint('Repeat with ' .. join(group.order, ', '))
  endif
  repeatMap = group
enddef

export def EscapeKey(ctx: P.Ctx): bool
  var state = ctx.state
  if state.HasAvy()
    Avy.Cancel(ctx)
    ctx.ui.Refresh(state)
    return true
  endif
  var hadTransient = state.pending != '' || !empty(repeatMap)
  state.pending = ''
  repeatMap = {}
  ctx.ui.HideWhichKey()
  ctx.ui.ClearExpandHints()
  if state.mode == St.INSERT
    ctx.SetMode(St.NORMAL)
    ctx.ui.Refresh(state)
    return true
  endif
  if state.mode == St.KEYPAD
    Keypad.Exit(ctx)
    ctx.ui.Refresh(state)
    return true
  endif
  var sels = ctx.port.GetSelections()
  if len(sels) > 1 || Sel.HasSelection(sels[0])
    Sel.CancelAll(ctx)
    ctx.ui.Refresh(state)
    return true
  endif
  return hadTransient
enddef

Registry.Register({
  'meow-keypad': (ctx: P.Ctx) => EnterKeypad(ctx),
  'repeat': (ctx: P.Ctx) => RepeatLast(ctx),
})
