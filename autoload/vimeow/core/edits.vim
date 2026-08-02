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
import autoload 'vimeow/core/selections.vim' as Sel
import autoload 'vimeow/core/grab.vim' as Grab

def AllowModify(ctx: P.Ctx): bool
  return ctx.port.IsWritable()
enddef

export def BlockedReadOnly(ctx: P.Ctx): bool
  if AllowModify(ctx)
    return false
  endif
  ctx.ui.Hint('Buffer is read-only')
  return true
enddef

def EditCarets(ctx: P.Ctx, Compute: func(P.SelRange, number, number): dict<any>)
  var sels = ctx.port.GetSelections()
  var order: list<dict<any>> = []
  var index = 0
  for sel in sels
    add(order, {sel: sel, index: index, start: sel.Lo()})
    index += 1
  endfor
  sort(order, (a, b) => a.start != b.start ? b.start - a.start : a.index - b.index)

  var edits: list<P.TextEdit> = []
  var results: dict<any> = {}
  for item in order
    var computed = Compute(item.sel, item.start, item.sel.Hi())
    if computed.edit != null_object
      add(edits, computed.edit)
    endif
    results[string(item.index)] = computed
  endfor

  var newSels: list<P.SelRange> = repeat([null_object], len(sels))
  var delta = 0
  for i in range(len(order) - 1, 0, -1)
    var item = order[i]
    var computed = results[string(item.index)]
    newSels[item.index] = P.SelRange.new(computed.sel.anchor + delta, computed.sel.active + delta)
    if computed.edit != null_object
      delta += len(computed.edit.text) - (computed.edit.end - computed.edit.start)
    endif
  endfor

  Grab.AdjustForEdits(ctx.state, edits)
  if !empty(edits)
    ctx.port.Edit(edits)
  endif
  ctx.port.SetSelections(newSels)
enddef

def DeleteSelectionOrCharForward(text: string, start: number, end: number): dict<any>
  if start != end
    return {edit: P.TextEdit.new(start, end, ''), sel: P.SelRange.new(start, start)}
  endif
  if start < len(text)
    return {edit: P.TextEdit.new(start, start + 1, ''), sel: P.SelRange.new(start, start)}
  endif
  return {edit: null_object, sel: P.SelRange.new(start, start)}
enddef

def EnterInsertAt(ctx: P.Ctx, atHigh: bool)
  var moved: list<P.SelRange> = []
  for sel in ctx.port.GetSelections()
    var at = atHigh ? sel.Hi() : sel.Lo()
    add(moved, P.SelRange.new(at, at))
  endfor
  ctx.port.SetSelections(moved)
  ctx.state.selType = St.SEL_NONE
  Sel.ResetSelectionMemory(ctx.state)
  ctx.SetMode(St.INSERT)
enddef

def OpenBelow(ctx: P.Ctx)
  if BlockedReadOnly(ctx)
    return
  endif
  Sel.Collapse(ctx)
  var text = ctx.port.GetText()
  var eol = T.LineEnd(text, T.LineOfOffset(text, Sel.Primary(ctx).active))
  var edits = [P.TextEdit.new(eol, eol, "\n")]
  Grab.AdjustForEdits(ctx.state, edits)
  ctx.port.Edit(edits)
  ctx.port.SetSelections([P.SelRange.new(eol + 1, eol + 1)])
  ctx.SetMode(St.INSERT)
enddef

def OpenAbove(ctx: P.Ctx)
  if BlockedReadOnly(ctx)
    return
  endif
  Sel.Collapse(ctx)
  var text = ctx.port.GetText()
  var lineStartOffset = T.LineStart(text, T.LineOfOffset(text, Sel.Primary(ctx).active))
  var edits = [P.TextEdit.new(lineStartOffset, lineStartOffset, "\n")]
  Grab.AdjustForEdits(ctx.state, edits)
  ctx.port.Edit(edits)
  ctx.port.SetSelections([P.SelRange.new(lineStartOffset, lineStartOffset)])
  ctx.SetMode(St.INSERT)
enddef

def OpenLine(ctx: P.Ctx)
  if BlockedReadOnly(ctx)
    return
  endif
  Sel.Collapse(ctx)
  var at = Sel.Primary(ctx).active
  var edits = [P.TextEdit.new(at, at, "\n")]
  Grab.AdjustForEdits(ctx.state, edits)
  ctx.port.Edit(edits)
  ctx.port.SetSelections([P.SelRange.new(at, at)])
enddef

def HorizontalSpace(ctx: P.Ctx, replacement: string)
  if BlockedReadOnly(ctx)
    return
  endif
  Sel.Collapse(ctx)
  var text = ctx.port.GetText()
  var at = Sel.Primary(ctx).active
  var from = at
  while from > 0 && T.IsBlank(T.CharAt(text, from - 1))
    from -= 1
  endwhile
  var to = at
  while to < len(text) && T.IsBlank(T.CharAt(text, to))
    to += 1
  endwhile
  if from == to && replacement == ''
    return
  endif
  var edits = [P.TextEdit.new(from, to, replacement)]
  Grab.AdjustForEdits(ctx.state, edits)
  ctx.port.Edit(edits)
  var caret = from + len(replacement)
  ctx.port.SetSelections([P.SelRange.new(caret, caret)])
enddef

def Change(ctx: P.Ctx)
  if !AllowModify(ctx)
    return
  endif
  var text = ctx.port.GetText()
  var prim = Sel.Primary(ctx)
  if !Sel.HasSelection(prim) && prim.active >= len(text)
    return
  endif
  EditCarets(ctx, (_sel, start, end) => DeleteSelectionOrCharForward(text, start, end))
  ctx.state.selType = St.SEL_NONE
  ctx.SetMode(St.INSERT)
enddef

def Delete(ctx: P.Ctx)
  if BlockedReadOnly(ctx)
    return
  endif
  var text = ctx.port.GetText()
  EditCarets(ctx, (_sel, start, end) => DeleteSelectionOrCharForward(text, start, end))
  ctx.state.selType = St.SEL_NONE
enddef

def BackwardDelete(ctx: P.Ctx)
  if !AllowModify(ctx)
    return
  endif
  def Compute(sel: P.SelRange, start: number, end: number): dict<any>
    if start != end
      return {edit: P.TextEdit.new(start, end, ''), sel: P.SelRange.new(start, start)}
    endif
    if start > 0
      return {edit: P.TextEdit.new(start - 1, start, ''), sel: P.SelRange.new(start - 1, start - 1)}
    endif
    return {edit: null_object, sel: P.SelRange.new(start, start)}
  enddef
  EditCarets(ctx, Compute)
  ctx.state.selType = St.SEL_NONE
enddef

def KillRange(ctx: P.Ctx, sel: P.SelRange, text: string): dict<number>
  var start = sel.Lo()
  var end = sel.Hi()
  if ctx.state.selType == St.SEL_LINE && sel.active >= sel.anchor && end < len(text)
    if T.CharAt(text, end) == "\r"
      end += 1
    endif
    if end < len(text) && T.CharAt(text, end) == "\n"
      end += 1
    endif
  endif
  return {start: start, end: end}
enddef

def RegionsInOrder(sels: list<P.SelRange>): list<P.SelRange>
  var regions: list<P.SelRange> = []
  for sel in sels
    if sel.anchor != sel.active
      add(regions, sel)
    endif
  endfor
  sort(regions, (a, b) => a.Lo() - b.Lo())
  return regions
enddef

def JoinedKillText(ctx: P.Ctx, text: string, regions: list<P.SelRange>): string
  var parts: list<string> = []
  for sel in regions
    var killed = KillRange(ctx, sel, text)
    add(parts, T.Slice(text, killed.start, killed.end))
  endfor
  return join(parts, "\n")
enddef

def JoinKill(ctx: P.Ctx)
  var text = ctx.port.GetText()
  var prim = Sel.Primary(ctx)
  var start = prim.Lo()
  var end = prim.Hi()
  var before = start > 0 ? T.CharAt(text, start - 1) : "\n"
  var after = end < len(text) ? T.CharAt(text, end) : "\n"
  var space = before != "\n" && after != "\n"
      && before !~ '^\s$' && after !~ '^\s$'
      && stridx(')]}.,;:', after) < 0
      && stridx('([{', before) < 0
  var edits = [P.TextEdit.new(start, end, space ? ' ' : '')]
  Grab.AdjustForEdits(ctx.state, edits)
  ctx.port.Edit(edits)
  ctx.port.SetSelections([P.SelRange.new(start, start)])
  ctx.state.selType = St.SEL_NONE
  ctx.state.selExpand = false
enddef

def Kill(ctx: P.Ctx)
  if !AllowModify(ctx)
    return
  endif
  var state = ctx.state
  var text = ctx.port.GetText()
  var prim = Sel.Primary(ctx)
  if state.selType == St.SEL_JOIN && Sel.HasSelection(prim)
    JoinKill(ctx)
    return
  endif
  if Sel.HasSelection(prim)
    ctx.clipboard.Write(JoinedKillText(ctx, text, RegionsInOrder(ctx.port.GetSelections())))
    def Compute(sel: P.SelRange, start: number, end: number): dict<any>
      if start == end
        return {edit: null_object, sel: sel}
      endif
      var killed = KillRange(ctx, sel, text)
      return {
        edit: P.TextEdit.new(killed.start, killed.end, ''),
        sel: P.SelRange.new(killed.start, killed.start),
      }
    enddef
    EditCarets(ctx, Compute)
    state.selType = St.SEL_NONE
    return
  endif
  if len(text) == 0
    return
  endif
  var caret = prim.active
  var caretLine = T.LineOfOffset(text, caret)
  var eol = T.LineEnd(text, caretLine)
  var stop = caret == eol ? T.LineStart(text, caretLine + 1) : eol
  if stop > caret
    ctx.clipboard.Write(T.Slice(text, caret, stop))
    var edits = [P.TextEdit.new(caret, stop, '')]
    Grab.AdjustForEdits(state, edits)
    ctx.port.Edit(edits)
    ctx.port.SetSelections([P.SelRange.new(caret, caret)])
  endif
enddef

def Save(ctx: P.Ctx)
  var text = ctx.port.GetText()
  var sels = ctx.port.GetSelections()
  var withSel = RegionsInOrder(sels)
  if empty(withSel)
    return
  endif
  ctx.clipboard.Write(JoinedKillText(ctx, text, withSel))
  var moved: list<P.SelRange> = []
  for sel in sels
    if sel.anchor == sel.active
      add(moved, sel)
    else
      var killed = KillRange(ctx, sel, text)
      var caret = sel.active >= sel.anchor ? killed.end : killed.start
      add(moved, P.SelRange.new(caret, caret))
    endif
  endfor
  ctx.port.SetSelections(moved)
  ctx.state.selType = St.SEL_NONE
  ctx.state.selExpand = false
enddef

def Yank(ctx: P.Ctx)
  if BlockedReadOnly(ctx)
    return
  endif
  var clip = ctx.clipboard.Read()
  if clip == ''
    return
  endif
  EditCarets(ctx, (sel, _start, _end) => ({
    edit: P.TextEdit.new(sel.active, sel.active, clip),
    sel: P.SelRange.new(sel.active + len(clip), sel.active + len(clip)),
  }))
enddef

def Replace(ctx: P.Ctx)
  if !AllowModify(ctx)
    return
  endif
  if !Sel.HasSelection(Sel.Primary(ctx))
    return
  endif
  var raw = ctx.clipboard.Read()
  if raw == ''
    return
  endif
  var clip = substitute(raw, '\n\+$', '', '')
  def Compute(sel: P.SelRange, start: number, end: number): dict<any>
    if start == end
      return {edit: null_object, sel: sel}
    endif
    return {
      edit: P.TextEdit.new(start, end, clip),
      sel: P.SelRange.new(start + len(clip), start + len(clip)),
    }
  enddef
  EditCarets(ctx, Compute)
  ctx.state.selType = St.SEL_NONE
enddef

def CapitalizedWords(slice: string): string
  var IsWord = T.CharPred(false)
  var out: list<string> = []
  var inWord = false
  for i in range(len(slice))
    var char = slice[i]
    if IsWord(char)
      add(out, inWord ? tolower(char) : toupper(char))
      inWord = true
    else
      add(out, char)
      inWord = false
    endif
  endfor
  return join(out, '')
enddef

def Casified(slice: string, op: string): string
  if op == 'upcase'
    return toupper(slice)
  endif
  if op == 'downcase'
    return tolower(slice)
  endif
  return CapitalizedWords(slice)
enddef

def CaseWord(ctx: P.Ctx, op: string)
  if BlockedReadOnly(ctx)
    return
  endif
  var count = ctx.state.TakeCount(1)
  if count == 0
    return
  endif
  var hadSelection = Sel.HasSelection(Sel.Primary(ctx))
  var text = ctx.port.GetText()
  var IsWord = T.CharPred(false)
  def Compute(sel: P.SelRange, _start: number, _end: number): dict<any>
    var from = sel.active
    var target = count > 0
        ? T.WordsNextEnd(text, from, count, IsWord)
        : T.WordsPrevStart(text, from, -count, IsWord)
    var start = min([from, target])
    var end = max([from, target])
    if start == end
      return {edit: null_object, sel: sel}
    endif
    var caret = count > 0 ? end : from
    return {
      edit: P.TextEdit.new(start, end, Casified(T.Slice(text, start, end), op)),
      sel: P.SelRange.new(caret, caret),
    }
  enddef
  EditCarets(ctx, Compute)
  if hadSelection
    Sel.Collapse(ctx)
  endif
enddef

def KillWord(ctx: P.Ctx)
  if BlockedReadOnly(ctx)
    return
  endif
  var count = ctx.state.TakeCount(1)
  if count == 0
    return
  endif
  var text = ctx.port.GetText()
  var IsWord = T.CharPred(false)
  def RangeAt(from: number): dict<number>
    var target = count > 0
        ? T.WordsNextEnd(text, from, count, IsWord)
        : T.WordsPrevStart(text, from, -count, IsWord)
    return {start: min([from, target]), end: max([from, target])}
  enddef
  var killed: list<dict<number>> = []
  for sel in ctx.port.GetSelections()
    var range = RangeAt(sel.active)
    if range.start != range.end
      add(killed, range)
    endif
  endfor
  sort(killed, (a, b) => a.start - b.start)
  if empty(killed)
    return
  endif
  var parts: list<string> = []
  for range in killed
    add(parts, T.Slice(text, range.start, range.end))
  endfor
  ctx.clipboard.Write(join(parts, "\n"))
  def Compute(sel: P.SelRange, _start: number, _end: number): dict<any>
    var range = RangeAt(sel.active)
    if range.start == range.end
      return {edit: null_object, sel: P.SelRange.new(sel.active, sel.active)}
    endif
    return {
      edit: P.TextEdit.new(range.start, range.end, ''),
      sel: P.SelRange.new(range.start, range.start),
    }
  enddef
  EditCarets(ctx, Compute)
  ctx.state.selType = St.SEL_NONE
  ctx.state.selExpand = false
enddef

def Undo(ctx: P.Ctx)
  if Sel.HasSelection(Sel.Primary(ctx))
    Sel.Cancel(ctx)
  endif
  ctx.port.Undo()
enddef

def UndoInSelection(ctx: P.Ctx)
  if Sel.HasSelection(Sel.Primary(ctx))
    ctx.port.Undo()
  endif
enddef

export def Commands(): dict<func>
  return {
    'meow-insert': (ctx: P.Ctx) => EnterInsertAt(ctx, false),
    'meow-append': (ctx: P.Ctx) => EnterInsertAt(ctx, true),
    'meow-open-above': OpenAbove,
    'meow-open-below': OpenBelow,
    'meow-change': Change,
    'meow-delete': Delete,
    'meow-backward-delete': BackwardDelete,
    'meow-kill': Kill,
    'meow-save': Save,
    'meow-yank': Yank,
    'meow-replace': Replace,
    'meow-undo': Undo,
    'meow-undo-in-selection': UndoInSelection,
    'upcase-word': (ctx: P.Ctx) => CaseWord(ctx, 'upcase'),
    'downcase-word': (ctx: P.Ctx) => CaseWord(ctx, 'downcase'),
    'capitalize-word': (ctx: P.Ctx) => CaseWord(ctx, 'capitalize'),
    'kill-word': KillWord,
    'open-line': OpenLine,
    'delete-horizontal-space': (ctx: P.Ctx) => HorizontalSpace(ctx, ''),
    'just-one-space': (ctx: P.Ctx) => HorizontalSpace(ctx, ' '),
  }
enddef
