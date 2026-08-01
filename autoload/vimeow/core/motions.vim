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
import autoload 'vimeow/core/search.vim' as Search
import autoload 'vimeow/core/grab.vim' as Grab

const SYMBOL_BOUNDARY = '\%([0-9A-Za-z_$]\)'

const VERTICAL = {
  'meow-next': true,
  'meow-prev': true,
  'meow-next-expand': true,
  'meow-prev-expand': true,
  'next-line': true,
  'previous-line': true,
}

def LineStartTarget(text: string, off: number): number
  return T.LineStart(text, T.LineOfOffset(text, off))
enddef

def LineEndTarget(text: string, off: number): number
  return T.LineEnd(text, T.LineOfOffset(text, off))
enddef

def IndentationTarget(text: string, off: number): number
  var line = T.LineOfOffset(text, off)
  var stop = T.LineEnd(text, line)
  var at = T.LineStart(text, line)
  while at < stop && T.IsBlank(T.CharAt(text, at))
    at += 1
  endwhile
  return at
enddef

def WordType(symbol: bool): string
  return symbol ? St.SEL_SYMBOL : St.SEL_WORD
enddef

def CharSelActive(ctx: P.Ctx): bool
  return ctx.st.selType == St.SEL_CHAR && Sel.HasSelection(Sel.Primary(ctx))
enddef

def MovedChar(length: number, sel: P.SelRange, dx: number, extend: bool): P.SelRange
  var active = T.Clamp(sel.active + dx, 0, length)
  return P.SelRange.new(extend ? sel.anchor : active, active)
enddef

def MovedLine(
    text: string, sel: P.SelRange, dy: number, extend: bool, goal: number): P.SelRange
  var ln = T.LineOfOffset(text, sel.active)
  var target = ln + dy
  var active = 0
  if target < 0
    active = 0
  elseif target > T.LineCount(text) - 1
    active = len(text)
  else
    var col = goal >= 0 ? goal : sel.active - T.LineStart(text, ln)
    var bol = T.LineStart(text, target)
    active = bol + min([col, T.LineEnd(text, target) - bol])
  endif
  return P.SelRange.new(extend ? sel.anchor : active, active)
enddef

def GoalColumn(ctx: P.Ctx): number
  var st = ctx.st
  if st.goalColumn < 0 || st.lastCommand == '' || !get(VERTICAL, st.lastCommand, false)
    var text = ctx.port.GetText()
    var p = Sel.Primary(ctx).active
    st.goalColumn = p - T.LineStart(text, T.LineOfOffset(text, p))
  endif
  return st.goalColumn
enddef

def MoveChar(ctx: P.Ctx, dx: number)
  var extend = CharSelActive(ctx)
  if !extend && Sel.HasSelection(Sel.Primary(ctx))
    Sel.Cancel(ctx)
  endif
  var length = len(ctx.port.GetText())
  var moved: list<P.SelRange> = []
  for s in ctx.port.GetSelections()
    add(moved, MovedChar(length, s, dx, extend))
  endfor
  ctx.port.SetSelections(moved)
enddef

def MoveLine(ctx: P.Ctx, dy: number)
  var extend = CharSelActive(ctx)
  if !extend
    Sel.Cancel(ctx)
  endif
  var goal = GoalColumn(ctx)
  var text = ctx.port.GetText()
  var moved: list<P.SelRange> = []
  var i = 0
  for s in ctx.port.GetSelections()
    add(moved, MovedLine(text, s, dy, extend, i == 0 ? goal : -1))
    i += 1
  endfor
  ctx.port.SetSelections(moved)
enddef

def MoveExpand(ctx: P.Ctx, dx: number, dy: number)
  var text = ctx.port.GetText()
  var goal = dy != 0 ? GoalColumn(ctx) : -1
  var sels = ctx.port.GetSelections()
  var before = sels[0].active
  var moved: list<P.SelRange> = []
  var i = 0
  for s in sels
    if dy == 0
      add(moved, MovedChar(len(text), s, dx, true))
    else
      add(moved, MovedLine(text, s, dy, true, i == 0 ? goal : -1))
    endif
    i += 1
  endfor
  ctx.port.SetSelections(moved)
  Sel.RecordSelect(ctx, St.SEL_CHAR, moved[0].anchor, moved[0].active, true, before)
  ctx.st.selType = St.SEL_CHAR
  ctx.st.selExpand = true
  Grab.Beacon(ctx)
enddef

def CharOrExpand(ctx: P.Ctx, dx: number)
  if Sel.HasSelection(Sel.Primary(ctx))
    MoveExpand(ctx, dx, 0)
  else
    MoveChar(ctx, dx)
  endif
enddef

def LineOrExpand(ctx: P.Ctx, dy: number)
  if Sel.HasSelection(Sel.Primary(ctx))
    MoveExpand(ctx, 0, dy)
  else
    MoveLine(ctx, dy)
  endif
enddef

def MoveToOrExpand(ctx: P.Ctx, selType: string, Target: func(string, number): number)
  var text = ctx.port.GetText()
  var extend = Sel.HasSelection(Sel.Primary(ctx))
  var before = Sel.Primary(ctx).active
  var moved: list<P.SelRange> = []
  for s in ctx.port.GetSelections()
    var active = T.Clamp(Target(text, s.active), 0, len(text))
    add(moved, P.SelRange.new(extend ? s.anchor : active, active))
  endfor
  ctx.port.SetSelections(moved)
  if extend
    Sel.RecordSelect(ctx, selType, moved[0].anchor, moved[0].active, true, before)
    ctx.st.selType = selType
    ctx.st.selExpand = true
    Grab.Beacon(ctx)
  endif
enddef

def WordOrExpand(ctx: P.Ctx, n: number)
  var Pred = T.CharPred(false)
  MoveToOrExpand(ctx, St.SEL_WORD, (text: string, off: number): number => n >= 0
      ? T.WordsNextEnd(text, off, n, Pred)
      : T.WordsPrevStart(text, off, -n, Pred))
enddef

def SentenceOrExpand(ctx: P.Ctx, n: number)
  MoveToOrExpand(ctx, St.SEL_CHAR, (text: string, off: number): number => n >= 0
      ? T.NextSentenceEnd(text, off, n)
      : T.PrevSentenceStart(text, off, -n))
enddef

def ParagraphOrExpand(ctx: P.Ctx, n: number)
  MoveToOrExpand(ctx, St.SEL_CHAR, (text: string, off: number): number => n >= 0
      ? T.NextParagraphEnd(text, off, n)
      : T.PrevParagraphStart(text, off, -n))
enddef

def NextLineStart(text: string, offset: number): number
  if len(text) == 0
    return 0
  endif
  var ln = T.LineOfOffset(text, T.Clamp(offset, 0, len(text)))
  if ln >= T.LineCount(text) - 1
    return len(text)
  endif
  return T.LineStart(text, ln + 1)
enddef

def BufferBoundary(ctx: P.Ctx, top: bool)
  var counted = ctx.st.pendingCount != 0 || ctx.st.negative
  var n = ctx.st.TakeCount(1)
  MoveToOrExpand(ctx, St.SEL_CHAR, (text: string, _off: number): number => {
    var length = len(text)
    if !counted
      return top ? 0 : length
    endif
    var q = length * n / 10
    var tenth = q
    var raw = T.Clamp(top ? tenth : length - tenth, 0, length)
    return NextLineStart(text, raw)
  })
enddef

def WordMotion(ctx: P.Ctx, symbol: bool, n: number)
  if n == 0
    return
  endif
  var text = ctx.port.GetText()
  var selType = WordType(symbol)
  var sel = Sel.Primary(ctx)
  var lo = sel.Lo()
  var hi = sel.Hi()
  if !(Sel.HasSelection(sel) && ctx.st.selType == selType)
    Sel.Cancel(ctx)
  endif
  var extend = ctx.st.selExpand && ctx.st.selType == selType && Sel.HasSelection(sel)
  var from = extend ? (n < 0 ? lo : hi) : sel.active
  var Pred = T.CharPred(symbol)
  var target = n > 0
      ? T.WordsNextEnd(text, from, n, Pred)
      : T.WordsPrevStart(text, from, -n, Pred)
  if target == from
    return
  endif
  var anchor = extend
      ? (n < 0 ? hi : lo)
      : T.WordsFixSelectionMark(text, target, from, Pred)
  Sel.Select(ctx, selType, anchor, target, extend)
enddef

def MarkWord(ctx: P.Ctx, symbol: bool)
  var neg = ctx.st.TakeCount(1) < 0
  var text = ctx.port.GetText()
  var b = T.WordsBoundsAt(text, Sel.Primary(ctx).active, T.CharPred(symbol))
  if empty(b)
    ctx.ui.Hint('No word here')
    return
  endif
  var s = b[0]
  var e = b[1]
  if neg
    Sel.Select(ctx, WordType(symbol), e, s, true)
  else
    Sel.Select(ctx, WordType(symbol), s, e, true)
  endif
  var quoted = T.RegexQuote(T.Slice(text, s, e))
  if symbol
    Search.Push(ctx.st, SYMBOL_BOUNDARY .. '\@<!' .. quoted .. SYMBOL_BOUNDARY .. '\@!')
  else
    Search.Push(ctx.st, '\<' .. quoted .. '\>')
  endif
enddef

def Line(ctx: P.Ctx)
  var text = ctx.port.GetText()
  if len(text) == 0
    return
  endif
  var n = ctx.st.TakeCount(1)
  var lastLine = T.LineCount(text) - 1
  if ctx.st.selType == St.SEL_LINE && ctx.st.selExpand && Sel.HasSelection(Sel.Primary(ctx))
    var caretLn = T.LineOfOffset(text, Sel.Primary(ctx).active)
    if Sel.BackwardP(ctx)
      var ln = max([caretLn - abs(n), 0])
      Sel.Select(ctx, St.SEL_LINE, Sel.Mark(ctx), T.LineStart(text, ln), true)
    else
      var ln = min([caretLn + abs(n), lastLine])
      Sel.Select(ctx, St.SEL_LINE, Sel.Mark(ctx), T.LineEnd(text, ln), true)
    endif
    return
  endif
  var ln = T.LineOfOffset(text, Sel.Primary(ctx).active)
  if n < 0
    var startLn = max([ln + n + 1, 0])
    Sel.Select(ctx, St.SEL_LINE, T.LineEnd(text, ln), T.LineStart(text, startLn), true)
  else
    var endLn = min([ln + n - 1, lastLine])
    Sel.Select(ctx, St.SEL_LINE, T.LineStart(text, ln), T.LineEnd(text, endLn), true)
  endif
enddef

def GotoLine(ctx: P.Ctx)
  var input = ctx.ui.Input('Goto line:', '')
  if input == ''
    return
  endif
  var text = ctx.port.GetText()
  if len(text) == 0
    return
  endif
  var ln = T.ParsedLineNumber(input, T.LineCount(text))
  if ln < 0
    return
  endif
  Sel.Select(ctx, St.SEL_LINE, T.LineStart(text, ln), T.LineEnd(text, ln), true)
enddef

export def FindTill(ctx: P.Ctx, ch: string, till: bool)
  var n = ctx.st.TakeCount(1)
  var text = ctx.port.GetText()
  var caret = Sel.Primary(ctx).active
  var target = T.NthCharTarget(text, ch, caret, abs(n), n < 0, till)
  if target < 0
    ctx.ui.Hint('char not found: ' .. ch)
    return
  endif
  ctx.st.lastFind = {ch: ch}
  Sel.Select(ctx, till ? St.SEL_TILL : St.SEL_FIND, caret, target, false)
enddef

export def Commands(): dict<func>
  return {
    'meow-left': (ctx: P.Ctx) => MoveChar(ctx, -ctx.st.TakeCount(1)),
    'meow-right': (ctx: P.Ctx) => MoveChar(ctx, ctx.st.TakeCount(1)),
    'meow-next': (ctx: P.Ctx) => MoveLine(ctx, ctx.st.TakeCount(1)),
    'meow-prev': (ctx: P.Ctx) => MoveLine(ctx, -ctx.st.TakeCount(1)),
    'meow-left-expand': (ctx: P.Ctx) => MoveExpand(ctx, -ctx.st.TakeCount(1), 0),
    'meow-right-expand': (ctx: P.Ctx) => MoveExpand(ctx, ctx.st.TakeCount(1), 0),
    'meow-next-expand': (ctx: P.Ctx) => MoveExpand(ctx, 0, ctx.st.TakeCount(1)),
    'meow-prev-expand': (ctx: P.Ctx) => MoveExpand(ctx, 0, -ctx.st.TakeCount(1)),
    'meow-next-word': (ctx: P.Ctx) => WordMotion(ctx, false, ctx.st.TakeCount(1)),
    'meow-next-symbol': (ctx: P.Ctx) => WordMotion(ctx, true, ctx.st.TakeCount(1)),
    'meow-back-word': (ctx: P.Ctx) => WordMotion(ctx, false, -ctx.st.TakeCount(1)),
    'meow-back-symbol': (ctx: P.Ctx) => WordMotion(ctx, true, -ctx.st.TakeCount(1)),
    'meow-mark-word': (ctx: P.Ctx) => MarkWord(ctx, false),
    'meow-mark-symbol': (ctx: P.Ctx) => MarkWord(ctx, true),
    'meow-line': Line,
    'meow-goto-line': GotoLine,
    'meow-find': (ctx: P.Ctx) => {
      ctx.st.pending = St.PENDING_FIND
    },
    'meow-till': (ctx: P.Ctx) => {
      ctx.st.pending = St.PENDING_TILL
    },
    'forward-char': (ctx: P.Ctx) => CharOrExpand(ctx, ctx.st.TakeCount(1)),
    'backward-char': (ctx: P.Ctx) => CharOrExpand(ctx, -ctx.st.TakeCount(1)),
    'next-line': (ctx: P.Ctx) => {
      LineOrExpand(ctx, ctx.st.TakeCount(1))
      ctx.st.lastCommand = 'next-line'
    },
    'previous-line': (ctx: P.Ctx) => {
      LineOrExpand(ctx, -ctx.st.TakeCount(1))
      ctx.st.lastCommand = 'previous-line'
    },
    'move-beginning-of-line': (ctx: P.Ctx) => MoveToOrExpand(ctx, St.SEL_CHAR, LineStartTarget),
    'move-end-of-line': (ctx: P.Ctx) => MoveToOrExpand(ctx, St.SEL_CHAR, LineEndTarget),
    'back-to-indentation': (ctx: P.Ctx) => MoveToOrExpand(ctx, St.SEL_CHAR, IndentationTarget),
    'forward-word': (ctx: P.Ctx) => WordOrExpand(ctx, ctx.st.TakeCount(1)),
    'backward-word': (ctx: P.Ctx) => WordOrExpand(ctx, -ctx.st.TakeCount(1)),
    'forward-sentence': (ctx: P.Ctx) => SentenceOrExpand(ctx, ctx.st.TakeCount(1)),
    'backward-sentence': (ctx: P.Ctx) => SentenceOrExpand(ctx, -ctx.st.TakeCount(1)),
    'beginning-of-buffer': (ctx: P.Ctx) => BufferBoundary(ctx, true),
    'end-of-buffer': (ctx: P.Ctx) => BufferBoundary(ctx, false),
    'forward-paragraph': (ctx: P.Ctx) => ParagraphOrExpand(ctx, ctx.st.TakeCount(1)),
    'backward-paragraph': (ctx: P.Ctx) => ParagraphOrExpand(ctx, -ctx.st.TakeCount(1)),
  }
enddef
