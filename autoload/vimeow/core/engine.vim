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
  if ctx.st.mode == St.KEYPAD
    return
  endif
  ctx.st.keypadPreviousState = ctx.st.mode
  ctx.SetMode(St.KEYPAD)
  ctx.ui.ScheduleWhichKey('keypad', '')
enddef

export def RunEmacsMotion(ctx: P.Ctx, command: string)
  if Registry.Has(command)
    Registry.COMMANDS[command](ctx)
  endif
  ctx.ui.Refresh(ctx.st)
enddef

def Resolve(ctx: P.Ctx, c: string, motion: bool): dict<any>
  if c == ' '
    return {command: 'meow-keypad', recursive: true}
  endif
  if ctx.st.noremapDepth == 0
    var cfg = Rc.Cfg()
    var user = motion ? get(cfg.motion, c, {}) : get(cfg.normal, c, {})
    if !empty(user)
      return user
    endif
  endif
  var d = Rc.Defaults()
  return motion ? get(d.motion, c, {}) : get(d.normal, c, {})
enddef

def ResolvePending(ctx: P.Ctx, p: string, c: string)
  if p == St.PENDING_FIND
    Motions.FindTill(ctx, c, false)
  elseif p == St.PENDING_TILL
    Motions.FindTill(ctx, c, true)
  else
    Structures.ThingSelect(ctx, p, c)
  endif
enddef

def StartsMultiKeyInput(st: St.MeowState, cmd: string): bool
  return st.pending != ''
      || (st.pendingCount != 0 && cmd != '' && strpart(cmd, 0, 12) == 'meow-expand-')
      || (st.negative && cmd == 'meow-negative-argument')
      || cmd == 'meow-keypad'
enddef

export def HandleChar(ctx: P.Ctx, c: string): bool
  var st = ctx.st
  if st.mode == St.INSERT
    return false
  endif
  if st.mode == St.KEYPAD
    Keypad.Key(ctx, c)
    st.lastCommand = 'keypad'
    ctx.ui.Refresh(st)
    return true
  endif
  if st.HasAvy()
    Avy.Key(ctx, c)
    st.lastCommand = 'avy'
    ctx.ui.Refresh(st)
    return true
  endif

  ctx.ui.HideWhichKey()
  ctx.ui.ClearExpandHints()

  var pend = st.pending
  var repeatBinding: dict<any> = {}
  if pend == '' && !empty(repeatMap)
    repeatBinding = get(repeatMap.map, c, {})
  endif
  if pend == '' && empty(repeatBinding)
    repeatMap = {}
  endif
  var motionish = st.mode == St.MOTION
  var binding: dict<any> = {}
  if pend == ''
    binding = empty(repeatBinding) ? Resolve(ctx, c, motionish) : repeatBinding
  endif
  var cmd = get(binding, 'command', '')

  if !st.replaying && cmd != 'repeat'
    if pend == '' && st.pendingCount == 0 && !st.negative
      st.unit = []
    endif
    add(st.unit, c)
  endif

  if pend != ''
    st.pending = ''
    ResolvePending(ctx, pend, c)
    st.lastCommand = 'pending'
  elseif !empty(binding)
    RunBinding(ctx, binding)
    var fallback = cmd != '' ? cmd : get(binding, 'action', '')
    st.lastCommand = fallback != '' ? fallback : st.lastCommand
  else
    st.lastCommand = ''
  endif

  if !st.replaying && cmd != 'repeat' && !StartsMultiKeyInput(st, cmd)
    st.lastKeys = copy(st.unit)
  endif

  ctx.ui.Refresh(st)
  return true
enddef

export def RepeatLast(ctx: P.Ctx)
  var st = ctx.st
  var keys = st.lastKeys
  if empty(keys)
    return
  endif
  st.replaying = true
  try
    for k in keys
      HandleChar(ctx, k)
    endfor
  finally
    st.replaying = false
  endtry
enddef

def Dispatch(ctx: P.Ctx, b: dict<any>)
  var st = ctx.st
  var command = get(b, 'command', '')
  if command != ''
    if Registry.Has(command)
      Registry.COMMANDS[command](ctx)
    else
      ctx.ui.Hint('Unknown meow command: ' .. command)
    endif
    return
  endif
  var action = get(b, 'action', '')
  if action != ''
    try
      ctx.ui.RunCommand(action)
    catch
      ctx.ui.Hint('Unknown command: ' .. action)
    endtry
    return
  endif
  var keys = get(b, 'keys', '')
  if keys == ''
    return
  endif
  if st.replayDepth >= MAX_REPLAY_DEPTH
    ctx.ui.Hint('vimeow: mapping recursion is too deep')
    return
  endif
  var savedReplaying = st.replaying
  var recursive = get(b, 'recursive', false)
  st.replaying = true
  st.replayDepth += 1
  if !recursive
    st.noremapDepth += 1
  endif
  try
    for i in range(len(keys))
      HandleChar(ctx, keys[i])
    endfor
  finally
    if !recursive
      st.noremapDepth -= 1
    endif
    st.replayDepth -= 1
    st.replaying = savedReplaying
  endtry
enddef

export def RunBinding(ctx: P.Ctx, b: dict<any>)
  Dispatch(ctx, b)
  var m = Rc.RepeatMapFor(b)
  if empty(m)
    return
  endif
  if empty(repeatMap)
    ctx.ui.Hint('Repeat with ' .. join(m.order, ', '))
  endif
  repeatMap = m
enddef

export def EscapeKey(ctx: P.Ctx): bool
  var st = ctx.st
  if st.HasAvy()
    Avy.Cancel(ctx)
    ctx.ui.Refresh(st)
    return true
  endif
  var hadTransient = st.pending != '' || !empty(repeatMap)
  st.pending = ''
  repeatMap = {}
  ctx.ui.HideWhichKey()
  ctx.ui.ClearExpandHints()
  if st.mode == St.INSERT
    ctx.SetMode(St.NORMAL)
    ctx.ui.Refresh(st)
    return true
  endif
  if st.mode == St.KEYPAD
    Keypad.Exit(ctx)
    ctx.ui.Refresh(st)
    return true
  endif
  var sels = ctx.port.GetSelections()
  if len(sels) > 1 || Sel.HasSelection(sels[0])
    Sel.CancelAll(ctx)
    ctx.ui.Refresh(st)
    return true
  endif
  return hadTransient
enddef

Registry.Register({
  'meow-keypad': (ctx: P.Ctx) => EnterKeypad(ctx),
  'repeat': (ctx: P.Ctx) => RepeatLast(ctx),
})
