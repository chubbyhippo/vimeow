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
  return T.FirstNonBlankOffset(text, T.LineStart(text, line), T.LineEnd(text, line))
enddef

def WordType(symbol: bool): string
  return symbol ? St.SEL_SYMBOL : St.SEL_WORD
enddef

def CharSelActive(ctx: P.Ctx): bool
  return ctx.state.selType == St.SEL_CHAR && Sel.HasSelection(Sel.Primary(ctx))
enddef

def MovedChar(length: number, sel: P.SelRange, dx: number, extend: bool): P.SelRange
  var active = T.Clamp(sel.active + dx, 0, length)
  return P.SelRange.new(extend ? sel.anchor : active, active)
enddef

def MovedLine(
    text: string, sel: P.SelRange, dy: number, extend: bool, goal: number): P.SelRange
  var caretLine = T.LineOfOffset(text, sel.active)
  var target = caretLine + dy
  var active = 0
  if target < 0
    active = 0
  elseif target > T.LineCount(text) - 1
    active = len(text)
  else
    var col = goal >= 0 ? goal : sel.active - T.LineStart(text, caretLine)
    var lineStartOffset = T.LineStart(text, target)
    active = lineStartOffset + min([col, T.LineEnd(text, target) - lineStartOffset])
  endif
  return P.SelRange.new(extend ? sel.anchor : active, active)
enddef

def GoalColumn(ctx: P.Ctx): number
  var state = ctx.state
  if state.goalColumn < 0 || state.lastCommand == '' || !get(VERTICAL, state.lastCommand, false)
    var text = ctx.port.GetText()
    var caret = Sel.Primary(ctx).active
    state.goalColumn = caret - T.LineStart(text, T.LineOfOffset(text, caret))
  endif
  return state.goalColumn
enddef

def MoveChar(ctx: P.Ctx, dx: number)
  var extend = CharSelActive(ctx)
  if !extend && Sel.HasSelection(Sel.Primary(ctx))
    Sel.Cancel(ctx)
  endif
  var length = len(ctx.port.GetText())
  var moved: list<P.SelRange> = []
  for sel in ctx.port.GetSelections()
    add(moved, MovedChar(length, sel, dx, extend))
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
  for sel in ctx.port.GetSelections()
    add(moved, MovedLine(text, sel, dy, extend, i == 0 ? goal : -1))
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
  for sel in sels
    if dy == 0
      add(moved, MovedChar(len(text), sel, dx, true))
    else
      add(moved, MovedLine(text, sel, dy, true, i == 0 ? goal : -1))
    endif
    i += 1
  endfor
  ctx.port.SetSelections(moved)
  Sel.RecordSelect(ctx, St.SEL_CHAR, moved[0].anchor, moved[0].active, true, before)
  ctx.state.selType = St.SEL_CHAR
  ctx.state.selExpand = true
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
  for sel in ctx.port.GetSelections()
    var active = T.Clamp(Target(text, sel.active), 0, len(text))
    add(moved, P.SelRange.new(extend ? sel.anchor : active, active))
  endfor
  ctx.port.SetSelections(moved)
  if extend
    Sel.RecordSelect(ctx, selType, moved[0].anchor, moved[0].active, true, before)
    ctx.state.selType = selType
    ctx.state.selExpand = true
    Grab.Beacon(ctx)
  endif
enddef

def WordOrExpand(ctx: P.Ctx, count: number)
  var IsWord = T.CharPred(false)
  MoveToOrExpand(ctx, St.SEL_WORD, (text: string, off: number): number => count >= 0
      ? T.WordsNextEnd(text, off, count, IsWord)
      : T.WordsPrevStart(text, off, -count, IsWord))
enddef

def SentenceOrExpand(ctx: P.Ctx, count: number)
  MoveToOrExpand(ctx, St.SEL_CHAR, (text: string, off: number): number => count >= 0
      ? T.NextSentenceEnd(text, off, count)
      : T.PrevSentenceStart(text, off, -count))
enddef

def ParagraphOrExpand(ctx: P.Ctx, count: number)
  MoveToOrExpand(ctx, St.SEL_CHAR, (text: string, off: number): number => count >= 0
      ? T.NextParagraphEnd(text, off, count)
      : T.PrevParagraphStart(text, off, -count))
enddef

def NextLineStart(text: string, offset: number): number
  if len(text) == 0
    return 0
  endif
  var line = T.LineOfOffset(text, T.Clamp(offset, 0, len(text)))
  if line >= T.LineCount(text) - 1
    return len(text)
  endif
  return T.LineStart(text, line + 1)
enddef

def BufferBoundary(ctx: P.Ctx, top: bool)
  var counted = ctx.state.pendingCount != 0 || ctx.state.negative
  var count = ctx.state.TakeCount(1)
  MoveToOrExpand(ctx, St.SEL_CHAR, (text: string, _off: number): number => {
    var length = len(text)
    if !counted
      return top ? 0 : length
    endif
    var tenths = length * count / 10
    var raw = T.Clamp(top ? tenths : length - tenths, 0, length)
    return NextLineStart(text, raw)
  })
enddef

def WordMotion(ctx: P.Ctx, symbol: bool, count: number)
  if count == 0
    return
  endif
  var text = ctx.port.GetText()
  var selType = WordType(symbol)
  var sel = Sel.Primary(ctx)
  var selStart = sel.SelStart()
  var selEnd = sel.SelEnd()
  if !(Sel.HasSelection(sel) && ctx.state.selType == selType)
    Sel.Cancel(ctx)
  endif
  var extend = ctx.state.selExpand && ctx.state.selType == selType && Sel.HasSelection(sel)
  var from = extend ? (count < 0 ? selStart : selEnd) : sel.active
  var IsWord = T.CharPred(symbol)
  var target = count > 0
      ? T.WordsNextEnd(text, from, count, IsWord)
      : T.WordsPrevStart(text, from, -count, IsWord)
  if target == from
    return
  endif
  var anchor = extend
      ? (count < 0 ? selEnd : selStart)
      : T.WordsFixSelectionMark(text, target, from, IsWord)
  Sel.Select(ctx, selType, anchor, target, extend)
enddef

def MarkWord(ctx: P.Ctx, symbol: bool)
  var neg = ctx.state.TakeCount(1) < 0
  var text = ctx.port.GetText()
  var bounds = T.WordsBoundsAt(text, Sel.Primary(ctx).active, T.CharPred(symbol))
  if empty(bounds)
    ctx.ui.Hint('No word here')
    return
  endif
  var start = bounds[0]
  var end = bounds[1]
  if neg
    Sel.Select(ctx, WordType(symbol), end, start, true)
  else
    Sel.Select(ctx, WordType(symbol), start, end, true)
  endif
  var quoted = T.RegexQuote(T.Slice(text, start, end))
  if symbol
    Search.Push(ctx.state, SYMBOL_BOUNDARY .. '\@<!' .. quoted .. SYMBOL_BOUNDARY .. '\@!')
  else
    Search.Push(ctx.state, '\<' .. quoted .. '\>')
  endif
enddef

def Line(ctx: P.Ctx)
  var text = ctx.port.GetText()
  if len(text) == 0
    return
  endif
  var count = ctx.state.TakeCount(1)
  var lastLine = T.LineCount(text) - 1
  if ctx.state.selType == St.SEL_LINE && ctx.state.selExpand && Sel.HasSelection(Sel.Primary(ctx))
    var caretLine = T.LineOfOffset(text, Sel.Primary(ctx).active)
    if Sel.BackwardP(ctx)
      var target = max([caretLine - abs(count), 0])
      Sel.Select(ctx, St.SEL_LINE, Sel.Mark(ctx), T.LineStart(text, target), true)
    else
      var target = min([caretLine + abs(count), lastLine])
      Sel.Select(ctx, St.SEL_LINE, Sel.Mark(ctx), T.LineEnd(text, target), true)
    endif
    return
  endif
  var caretLine = T.LineOfOffset(text, Sel.Primary(ctx).active)
  if count < 0
    var startLine = max([caretLine + count + 1, 0])
    Sel.Select(ctx, St.SEL_LINE, T.LineEnd(text, caretLine), T.LineStart(text, startLine), true)
  else
    var endLine = min([caretLine + count - 1, lastLine])
    Sel.Select(ctx, St.SEL_LINE, T.LineStart(text, caretLine), T.LineEnd(text, endLine), true)
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
  var line = T.ParsedLineNumber(input, T.LineCount(text))
  if line < 0
    return
  endif
  Sel.Select(ctx, St.SEL_LINE, T.LineStart(text, line), T.LineEnd(text, line), true)
enddef

export def FindTill(ctx: P.Ctx, char: string, till: bool)
  var count = ctx.state.TakeCount(1)
  var text = ctx.port.GetText()
  var caret = Sel.Primary(ctx).active
  var target = T.NthCharTarget(text, char, caret, abs(count), count < 0, till)
  if target < 0
    ctx.ui.Hint('char not found: ' .. char)
    return
  endif
  ctx.state.lastFind = {ch: char}
  Sel.Select(ctx, till ? St.SEL_TILL : St.SEL_FIND, caret, target, false)
enddef

export def Commands(): dict<func>
  return {
    'meow-left': (ctx: P.Ctx) => MoveChar(ctx, -ctx.state.TakeCount(1)),
    'meow-right': (ctx: P.Ctx) => MoveChar(ctx, ctx.state.TakeCount(1)),
    'meow-next': (ctx: P.Ctx) => MoveLine(ctx, ctx.state.TakeCount(1)),
    'meow-prev': (ctx: P.Ctx) => MoveLine(ctx, -ctx.state.TakeCount(1)),
    'meow-left-expand': (ctx: P.Ctx) => MoveExpand(ctx, -ctx.state.TakeCount(1), 0),
    'meow-right-expand': (ctx: P.Ctx) => MoveExpand(ctx, ctx.state.TakeCount(1), 0),
    'meow-next-expand': (ctx: P.Ctx) => MoveExpand(ctx, 0, ctx.state.TakeCount(1)),
    'meow-prev-expand': (ctx: P.Ctx) => MoveExpand(ctx, 0, -ctx.state.TakeCount(1)),
    'meow-next-word': (ctx: P.Ctx) => WordMotion(ctx, false, ctx.state.TakeCount(1)),
    'meow-next-symbol': (ctx: P.Ctx) => WordMotion(ctx, true, ctx.state.TakeCount(1)),
    'meow-back-word': (ctx: P.Ctx) => WordMotion(ctx, false, -ctx.state.TakeCount(1)),
    'meow-back-symbol': (ctx: P.Ctx) => WordMotion(ctx, true, -ctx.state.TakeCount(1)),
    'meow-mark-word': (ctx: P.Ctx) => MarkWord(ctx, false),
    'meow-mark-symbol': (ctx: P.Ctx) => MarkWord(ctx, true),
    'meow-line': Line,
    'meow-goto-line': GotoLine,
    'meow-find': (ctx: P.Ctx) => {
      ctx.state.pending = St.PENDING_FIND
    },
    'meow-till': (ctx: P.Ctx) => {
      ctx.state.pending = St.PENDING_TILL
    },
    'forward-char': (ctx: P.Ctx) => CharOrExpand(ctx, ctx.state.TakeCount(1)),
    'backward-char': (ctx: P.Ctx) => CharOrExpand(ctx, -ctx.state.TakeCount(1)),
    'next-line': (ctx: P.Ctx) => {
      LineOrExpand(ctx, ctx.state.TakeCount(1))
      ctx.state.lastCommand = 'next-line'
    },
    'previous-line': (ctx: P.Ctx) => {
      LineOrExpand(ctx, -ctx.state.TakeCount(1))
      ctx.state.lastCommand = 'previous-line'
    },
    'move-beginning-of-line': (ctx: P.Ctx) => MoveToOrExpand(ctx, St.SEL_CHAR, LineStartTarget),
    'move-end-of-line': (ctx: P.Ctx) => MoveToOrExpand(ctx, St.SEL_CHAR, LineEndTarget),
    'back-to-indentation': (ctx: P.Ctx) => MoveToOrExpand(ctx, St.SEL_CHAR, IndentationTarget),
    'forward-word': (ctx: P.Ctx) => WordOrExpand(ctx, ctx.state.TakeCount(1)),
    'backward-word': (ctx: P.Ctx) => WordOrExpand(ctx, -ctx.state.TakeCount(1)),
    'forward-sentence': (ctx: P.Ctx) => SentenceOrExpand(ctx, ctx.state.TakeCount(1)),
    'backward-sentence': (ctx: P.Ctx) => SentenceOrExpand(ctx, -ctx.state.TakeCount(1)),
    'beginning-of-buffer': (ctx: P.Ctx) => BufferBoundary(ctx, true),
    'end-of-buffer': (ctx: P.Ctx) => BufferBoundary(ctx, false),
    'forward-paragraph': (ctx: P.Ctx) => ParagraphOrExpand(ctx, ctx.state.TakeCount(1)),
    'backward-paragraph': (ctx: P.Ctx) => ParagraphOrExpand(ctx, -ctx.state.TakeCount(1)),
  }
enddef
