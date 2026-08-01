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
    add(order, {sel: sel, index: index, lo: sel.Lo()})
    index += 1
  endfor
  sort(order, (a, b) => a.lo != b.lo ? b.lo - a.lo : a.index - b.index)

  var edits: list<P.TextEdit> = []
  var results: dict<any> = {}
  for item in order
    var r = Compute(item.sel, item.lo, item.sel.Hi())
    if r.edit != null_object
      add(edits, r.edit)
    endif
    results[string(item.index)] = r
  endfor

  var newSels: list<P.SelRange> = repeat([null_object], len(sels))
  var delta = 0
  for i in range(len(order) - 1, 0, -1)
    var item = order[i]
    var r = results[string(item.index)]
    newSels[item.index] = P.SelRange.new(r.sel.anchor + delta, r.sel.active + delta)
    if r.edit != null_object
      delta += len(r.edit.text) - (r.edit.end - r.edit.start)
    endif
  endfor

  Grab.AdjustForEdits(ctx.st, edits)
  if !empty(edits)
    ctx.port.Edit(edits)
  endif
  ctx.port.SetSelections(newSels)
enddef

def DeleteSelectionOrCharForward(text: string, lo: number, hi: number): dict<any>
  if lo != hi
    return {edit: P.TextEdit.new(lo, hi, ''), sel: P.SelRange.new(lo, lo)}
  endif
  if lo < len(text)
    return {edit: P.TextEdit.new(lo, lo + 1, ''), sel: P.SelRange.new(lo, lo)}
  endif
  return {edit: null_object, sel: P.SelRange.new(lo, lo)}
enddef

def EnterInsertAt(ctx: P.Ctx, atHigh: bool)
  var moved: list<P.SelRange> = []
  for s in ctx.port.GetSelections()
    var o = atHigh ? s.Hi() : s.Lo()
    add(moved, P.SelRange.new(o, o))
  endfor
  ctx.port.SetSelections(moved)
  ctx.st.selType = St.SEL_NONE
  Sel.ResetSelectionMemory(ctx.st)
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
  Grab.AdjustForEdits(ctx.st, edits)
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
  var bol = T.LineStart(text, T.LineOfOffset(text, Sel.Primary(ctx).active))
  var edits = [P.TextEdit.new(bol, bol, "\n")]
  Grab.AdjustForEdits(ctx.st, edits)
  ctx.port.Edit(edits)
  ctx.port.SetSelections([P.SelRange.new(bol, bol)])
  ctx.SetMode(St.INSERT)
enddef

def OpenLine(ctx: P.Ctx)
  if BlockedReadOnly(ctx)
    return
  endif
  Sel.Collapse(ctx)
  var at = Sel.Primary(ctx).active
  var edits = [P.TextEdit.new(at, at, "\n")]
  Grab.AdjustForEdits(ctx.st, edits)
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
  Grab.AdjustForEdits(ctx.st, edits)
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
  EditCarets(ctx, (_s, lo, hi) => DeleteSelectionOrCharForward(text, lo, hi))
  ctx.st.selType = St.SEL_NONE
  ctx.SetMode(St.INSERT)
enddef

def Delete(ctx: P.Ctx)
  if BlockedReadOnly(ctx)
    return
  endif
  var text = ctx.port.GetText()
  EditCarets(ctx, (_s, lo, hi) => DeleteSelectionOrCharForward(text, lo, hi))
  ctx.st.selType = St.SEL_NONE
enddef

def BackwardDelete(ctx: P.Ctx)
  if !AllowModify(ctx)
    return
  endif
  def Compute(sel: P.SelRange, lo: number, hi: number): dict<any>
    if lo != hi
      return {edit: P.TextEdit.new(lo, hi, ''), sel: P.SelRange.new(lo, lo)}
    endif
    if lo > 0
      return {edit: P.TextEdit.new(lo - 1, lo, ''), sel: P.SelRange.new(lo - 1, lo - 1)}
    endif
    return {edit: null_object, sel: P.SelRange.new(lo, lo)}
  enddef
  EditCarets(ctx, Compute)
  ctx.st.selType = St.SEL_NONE
enddef

def KillRange(ctx: P.Ctx, sel: P.SelRange, text: string): dict<number>
  var lo = sel.Lo()
  var hi = sel.Hi()
  if ctx.st.selType == St.SEL_LINE && sel.active >= sel.anchor && hi < len(text)
    if T.CharAt(text, hi) == "\r"
      hi += 1
    endif
    if hi < len(text) && T.CharAt(text, hi) == "\n"
      hi += 1
    endif
  endif
  return {lo: lo, hi: hi}
enddef

def RegionsInOrder(sels: list<P.SelRange>): list<P.SelRange>
  var regions: list<P.SelRange> = []
  for s in sels
    if s.anchor != s.active
      add(regions, s)
    endif
  endfor
  sort(regions, (a, b) => a.Lo() - b.Lo())
  return regions
enddef

def JoinedKillText(ctx: P.Ctx, text: string, regions: list<P.SelRange>): string
  var parts: list<string> = []
  for s in regions
    var r = KillRange(ctx, s, text)
    add(parts, T.Slice(text, r.lo, r.hi))
  endfor
  return join(parts, "\n")
enddef

def JoinKill(ctx: P.Ctx)
  var text = ctx.port.GetText()
  var prim = Sel.Primary(ctx)
  var s = prim.Lo()
  var e = prim.Hi()
  var before = s > 0 ? T.CharAt(text, s - 1) : "\n"
  var after = e < len(text) ? T.CharAt(text, e) : "\n"
  var space = before != "\n" && after != "\n"
      && before !~ '^\s$' && after !~ '^\s$'
      && stridx(')]}.,;:', after) < 0
      && stridx('([{', before) < 0
  var edits = [P.TextEdit.new(s, e, space ? ' ' : '')]
  Grab.AdjustForEdits(ctx.st, edits)
  ctx.port.Edit(edits)
  ctx.port.SetSelections([P.SelRange.new(s, s)])
  ctx.st.selType = St.SEL_NONE
  ctx.st.selExpand = false
enddef

def Kill(ctx: P.Ctx)
  if !AllowModify(ctx)
    return
  endif
  var st = ctx.st
  var text = ctx.port.GetText()
  var prim = Sel.Primary(ctx)
  if st.selType == St.SEL_JOIN && Sel.HasSelection(prim)
    JoinKill(ctx)
    return
  endif
  if Sel.HasSelection(prim)
    ctx.clipboard.Write(JoinedKillText(ctx, text, RegionsInOrder(ctx.port.GetSelections())))
    def Compute(sel: P.SelRange, lo: number, hi: number): dict<any>
      if lo == hi
        return {edit: null_object, sel: sel}
      endif
      var r = KillRange(ctx, sel, text)
      return {edit: P.TextEdit.new(r.lo, r.hi, ''), sel: P.SelRange.new(r.lo, r.lo)}
    enddef
    EditCarets(ctx, Compute)
    st.selType = St.SEL_NONE
    return
  endif
  if len(text) == 0
    return
  endif
  var caret = prim.active
  var ln = T.LineOfOffset(text, caret)
  var eol = T.LineEnd(text, ln)
  var stop = caret == eol ? T.LineStart(text, ln + 1) : eol
  if stop > caret
    ctx.clipboard.Write(T.Slice(text, caret, stop))
    var edits = [P.TextEdit.new(caret, stop, '')]
    Grab.AdjustForEdits(st, edits)
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
  for s in sels
    if s.anchor == s.active
      add(moved, s)
    else
      var r = KillRange(ctx, s, text)
      var caret = s.active >= s.anchor ? r.hi : r.lo
      add(moved, P.SelRange.new(caret, caret))
    endif
  endfor
  ctx.port.SetSelections(moved)
  ctx.st.selType = St.SEL_NONE
  ctx.st.selExpand = false
enddef

def Yank(ctx: P.Ctx)
  if BlockedReadOnly(ctx)
    return
  endif
  var clip = ctx.clipboard.Read()
  if clip == ''
    return
  endif
  EditCarets(ctx, (sel, _lo, _hi) => ({
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
  def Compute(sel: P.SelRange, lo: number, hi: number): dict<any>
    if lo == hi
      return {edit: null_object, sel: sel}
    endif
    return {
      edit: P.TextEdit.new(lo, hi, clip),
      sel: P.SelRange.new(lo + len(clip), lo + len(clip)),
    }
  enddef
  EditCarets(ctx, Compute)
  ctx.st.selType = St.SEL_NONE
enddef

def CapitalizedWords(slice: string): string
  var Pred = T.CharPred(false)
  var out: list<string> = []
  var inWord = false
  for i in range(len(slice))
    var c = slice[i]
    if Pred(c)
      add(out, inWord ? tolower(c) : toupper(c))
      inWord = true
    else
      add(out, c)
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
  var n = ctx.st.TakeCount(1)
  if n == 0
    return
  endif
  var hadSelection = Sel.HasSelection(Sel.Primary(ctx))
  var text = ctx.port.GetText()
  var Pred = T.CharPred(false)
  def Compute(sel: P.SelRange, _lo: number, _hi: number): dict<any>
    var from = sel.active
    var target = n > 0
        ? T.WordsNextEnd(text, from, n, Pred)
        : T.WordsPrevStart(text, from, -n, Pred)
    var s = min([from, target])
    var e = max([from, target])
    if s == e
      return {edit: null_object, sel: sel}
    endif
    var caret = n > 0 ? e : from
    return {
      edit: P.TextEdit.new(s, e, Casified(T.Slice(text, s, e), op)),
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
  var n = ctx.st.TakeCount(1)
  if n == 0
    return
  endif
  var text = ctx.port.GetText()
  var Pred = T.CharPred(false)
  def RangeAt(from: number): dict<number>
    var target = n > 0
        ? T.WordsNextEnd(text, from, n, Pred)
        : T.WordsPrevStart(text, from, -n, Pred)
    return {lo: min([from, target]), hi: max([from, target])}
  enddef
  var killed: list<dict<number>> = []
  for sel in ctx.port.GetSelections()
    var r = RangeAt(sel.active)
    if r.lo != r.hi
      add(killed, r)
    endif
  endfor
  sort(killed, (a, b) => a.lo - b.lo)
  if empty(killed)
    return
  endif
  var parts: list<string> = []
  for r in killed
    add(parts, T.Slice(text, r.lo, r.hi))
  endfor
  ctx.clipboard.Write(join(parts, "\n"))
  def Compute(sel: P.SelRange, _lo: number, _hi: number): dict<any>
    var r = RangeAt(sel.active)
    if r.lo == r.hi
      return {edit: null_object, sel: P.SelRange.new(sel.active, sel.active)}
    endif
    return {edit: P.TextEdit.new(r.lo, r.hi, ''), sel: P.SelRange.new(r.lo, r.lo)}
  enddef
  EditCarets(ctx, Compute)
  ctx.st.selType = St.SEL_NONE
  ctx.st.selExpand = false
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
