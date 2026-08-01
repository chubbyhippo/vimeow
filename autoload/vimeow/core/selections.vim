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

import autoload 'vimeow/core/text.vim' as T
import autoload 'vimeow/core/state.vim' as St
import autoload 'vimeow/core/port.vim' as P
import autoload 'vimeow/core/hints.vim' as Hints
import autoload 'vimeow/core/grab.vim' as Grab

const SELECTION_HISTORY_LIMIT = 200
const EXPAND_ZERO_COUNT = 10

const EXPANDABLE = {
  [St.SEL_CHAR]: true,
  [St.SEL_WORD]: true,
  [St.SEL_SYMBOL]: true,
  [St.SEL_LINE]: true,
  [St.SEL_FIND]: true,
  [St.SEL_TILL]: true,
}

export def Primary(ctx: P.Ctx): P.SelRange
  return ctx.port.GetSelections()[0]
enddef

export def HasSelection(sel: P.SelRange): bool
  return sel.anchor != sel.active
enddef

export def Lo(sel: P.SelRange): number
  return sel.Lo()
enddef

export def Hi(sel: P.SelRange): number
  return sel.Hi()
enddef

export def BackwardP(ctx: P.Ctx): bool
  var sel = Primary(ctx)
  return HasSelection(sel) && sel.active < sel.anchor
enddef

export def Mark(ctx: P.Ctx): number
  var sel = Primary(ctx)
  return HasSelection(sel) ? sel.anchor : sel.active
enddef

def SameSaved(a: dict<any>, b: dict<any>): bool
  return a.type == b.type && a.expand == b.expand
      && a.anchor == b.anchor && a.active == b.active
enddef

export def RecordSelect(
    ctx: P.Ctx, selType: string, anchor: number, active: number,
    expand: bool, posBefore: number)
  var st = ctx.st
  var prev = st.lastSelection == null_object
      ? {type: '', expand: false, anchor: posBefore, active: posBefore}
      : {type: st.lastSelection.selType, expand: false,
         anchor: st.lastSelection.anchor, active: st.lastSelection.active}
  if st.lastSelection != null_object
    prev.expand = st.selExpand
  endif
  var history = st.selectionHistory
  var head = empty(history) ? null_object : history[-1]
  if head == null_object
      || !SameSaved({type: head.selType, expand: false,
                     anchor: head.anchor, active: head.active},
                    {type: prev.type, expand: false,
                     anchor: prev.anchor, active: prev.active})
    add(history, St.SavedSelection.new(prev.type, prev.anchor, prev.active))
  endif
  while len(history) > SELECTION_HISTORY_LIMIT
    remove(history, 0)
  endwhile
  st.lastSelection = St.SavedSelection.new(selType, anchor, active)
enddef

export def Select(
    ctx: P.Ctx, selType: string, markOff: number, point: number,
    expand: bool, push: bool = true)
  var port = ctx.port
  var st = ctx.st
  var length = len(port.GetText())
  var m = T.Clamp(markOff, 0, length)
  var p = T.Clamp(point, 0, length)
  var sels = port.GetSelections()
  if push
    RecordSelect(ctx, selType, m, p, expand, sels[0].active)
  else
    st.lastSelection = St.SavedSelection.new(selType, m, p)
  endif
  st.selType = selType
  st.selExpand = expand
  sels[0] = P.SelRange.new(m, p)
  port.SetSelections(sels)
  Grab.Beacon(ctx)
  ctx.ui.ShowExpandHints(Hints.ExpandHintPositions(ctx))
enddef

export def ResetSelectionMemory(st: St.MeowState)
  st.selectionHistory = []
  st.lastSelection = null_object
enddef

export def Collapse(ctx: P.Ctx)
  var sels = ctx.port.GetSelections()
  sels[0] = P.SelRange.new(sels[0].active, sels[0].active)
  ctx.port.SetSelections(sels)
  ctx.st.selType = St.SEL_NONE
  ctx.st.selExpand = false
enddef

export def Cancel(ctx: P.Ctx)
  Collapse(ctx)
  ResetSelectionMemory(ctx.st)
enddef

export def CancelAll(ctx: P.Ctx)
  var sels = ctx.port.GetSelections()
  if len(sels) > 1
    ctx.port.SetSelections([sels[0]])
  endif
  Cancel(ctx)
enddef

def Reverse(ctx: P.Ctx)
  var sel = Primary(ctx)
  if !HasSelection(sel)
    return
  endif
  var sels = ctx.port.GetSelections()
  sels[0] = P.SelRange.new(sel.active, sel.anchor)
  ctx.port.SetSelections(sels)
enddef

def Pop(ctx: P.Ctx)
  var st = ctx.st
  if HasSelection(Primary(ctx))
    if empty(st.selectionHistory)
      return
    endif
    var entry = remove(st.selectionHistory, -1)
    if entry.selType == ''
      var sels = ctx.port.GetSelections()
      sels[0] = P.SelRange.new(entry.active, entry.active)
      ctx.port.SetSelections(sels)
      Cancel(ctx)
      ctx.ui.Hint('No previous selection')
    else
      Select(ctx, entry.selType, entry.anchor, entry.active, false, false)
    endif
  elseif !Grab.Pop(ctx)
    ctx.ui.Hint('No previous selection')
  endif
enddef

def Expand(ctx: P.Ctx, n: number)
  var st = ctx.st
  var text = ctx.port.GetText()
  var back = BackwardP(ctx)
  var caret = Primary(ctx).active
  var target = -1
  if st.selType == St.SEL_CHAR
    target = caret + (back ? -n : n)
  elseif st.selType == St.SEL_WORD || st.selType == St.SEL_SYMBOL
    var Pred = T.CharPred(st.selType == St.SEL_SYMBOL)
    target = back ? T.WordsPrevStart(text, caret, n, Pred)
                  : T.WordsNextEnd(text, caret, n, Pred)
  elseif st.selType == St.SEL_LINE
    var ln = T.LineOfOffset(text, caret)
    target = back ? T.LineStart(text, max([ln - n, 0]))
                  : T.LineEnd(text, min([ln + n, T.LineCount(text) - 1]))
  elseif st.selType == St.SEL_FIND || st.selType == St.SEL_TILL
    if empty(st.lastFind)
      return
    endif
    var t = T.NthCharTarget(text, st.lastFind.ch, caret, n, back, st.selType == St.SEL_TILL)
    if t < 0
      return
    endif
    target = t
  else
    return
  endif
  Select(ctx, st.selType, Mark(ctx), target, false)
enddef

def ExpandOrCount(ctx: P.Ctx, n: number)
  var st = ctx.st
  if HasSelection(Primary(ctx)) && get(EXPANDABLE, st.selType, false)
    Expand(ctx, n == 0 ? EXPAND_ZERO_COUNT : n)
  else
    st.pendingCount = st.pendingCount * 10 + n
  endif
enddef

def ExpandCommand(n: number): func
  return (ctx: P.Ctx) => ExpandOrCount(ctx, n)
enddef

export def Commands(): dict<func>
  var cmds: dict<func> = {
    'meow-reverse': Reverse,
    'meow-cancel-selection': CancelAll,
    'meow-pop-selection': Pop,
  }
  for n in range(10)
    cmds['meow-expand-' .. n] = ExpandCommand(n)
  endfor
  return cmds
enddef
