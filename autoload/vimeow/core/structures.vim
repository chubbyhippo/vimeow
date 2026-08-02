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
import autoload 'vimeow/core/things.vim' as Things
import autoload 'vimeow/core/selections.vim' as Sel

const OPENS = '([{'
const CLOSES = ')]}'

def PendThing(ctx: P.Ctx, pending: string)
  ctx.state.pending = pending
  ctx.ui.ScheduleWhichKey('things', '')
enddef

export def ThingSelect(ctx: P.Ctx, kind: string, char: string)
  var off = Sel.Primary(ctx).active
  var bounds = kind == St.PENDING_BOUNDS
      ? Things.Bounds(ctx, char, off)
      : Things.Inner(ctx, char, off)
  if empty(bounds)
    ctx.ui.Hint("No thing '" .. char .. "' here")
    return
  endif
  if kind == St.PENDING_INNER
    Sel.Select(ctx, St.SEL_TRANSIENT, bounds.start, bounds.stop, false)
  elseif kind == St.PENDING_BOUNDS
    Sel.Select(ctx, St.SEL_TRANSIENT, bounds.stop, bounds.start, false)
  elseif kind == St.PENDING_BEGIN
    Sel.Select(ctx, St.SEL_TRANSIENT, off, bounds.start, false)
  elseif kind == St.PENDING_END
    Sel.Select(ctx, St.SEL_TRANSIENT, off, bounds.stop, false)
  endif
enddef

def EnclosingPair(text: string, start: number, end: number): dict<number>
  var stack: list<number> = []
  var best: dict<number> = {}
  var i = 0
  var length = len(text)
  while i < length
    var char = T.CharAt(text, i)
    if char == '"' || char == "'" || char == '`'
      var j = i + 1
      while j < length && T.CharAt(text, j) != char && T.CharAt(text, j) != "\n"
        if T.CharAt(text, j) == '\'
          j += 1
        endif
        j += 1
      endwhile
      i = (j < length && T.CharAt(text, j) == char) ? j + 1 : i + 1
    else
      if stridx(OPENS, char) >= 0
        add(stack, i)
      elseif stridx(CLOSES, char) >= 0
        var kind = stridx(CLOSES, char)
        while !empty(stack)
          var openAt = remove(stack, -1)
          if stridx(OPENS, T.CharAt(text, openAt)) == kind
            if openAt < start && i + 1 >= end
                && (empty(best) || i - openAt < best.close - best.open)
              best = {open: openAt, close: i}
            endif
            break
          endif
        endwhile
      endif
      i += 1
    endif
  endwhile
  return best
enddef

def Block(ctx: P.Ctx)
  var text = ctx.port.GetText()
  var sel = Sel.Primary(ctx)
  var active = ctx.state.selType == St.SEL_BLOCK && Sel.HasSelection(sel)
  var back = Sel.BackwardP(ctx) != (ctx.state.TakeCount(1) < 0)
  var start = active ? sel.Lo() : sel.active
  var end = active ? sel.Hi() : sel.active
  var pair = EnclosingPair(text, start, end)
  if empty(pair)
    ctx.ui.Hint('No enclosing block')
    return
  endif
  if back
    Sel.Select(ctx, St.SEL_BLOCK, pair.close + 1, pair.open, true)
  else
    Sel.Select(ctx, St.SEL_BLOCK, pair.open, pair.close + 1, true)
  endif
enddef

def ToBlock(ctx: P.Ctx)
  var text = ctx.port.GetText()
  var back = (ctx.state.selType == St.SEL_BLOCK && Sel.BackwardP(ctx)) || ctx.state.TakeCount(1) < 0
  var caret = Sel.Primary(ctx).active
  var pair = EnclosingPair(text, caret, caret)
  if empty(pair)
    ctx.ui.Hint('No enclosing block')
    return
  endif
  Sel.Select(ctx, St.SEL_BLOCK, caret, back ? pair.open : pair.close + 1, true)
enddef

def SelectJoin(ctx: P.Ctx, text: string, markLine: number, pointLine: number)
  var mark = T.LineEnd(text, markLine)
  var point = T.FirstNonBlankOffset(
    text, T.LineStart(text, pointLine), T.LineEnd(text, pointLine))
  Sel.Select(ctx, St.SEL_JOIN, mark, point, true)
enddef

def Join(ctx: P.Ctx)
  var text = ctx.port.GetText()
  if len(text) == 0
    return
  endif
  var count = ctx.state.TakeCount(1)
  var caretLine = T.LineOfOffset(text, Sel.Primary(ctx).active)
  if count >= 0
    var prevLine = caretLine - 1
    while prevLine >= 0 && T.IsBlankLine(text, prevLine)
      prevLine -= 1
    endwhile
    if prevLine < 0
      return
    endif
    SelectJoin(ctx, text, prevLine, caretLine)
  else
    var last = T.LineCount(text) - 1
    var nextLine = caretLine + 1
    while nextLine <= last && T.IsBlankLine(text, nextLine)
      nextLine += 1
    endwhile
    if nextLine > last
      return
    endif
    SelectJoin(ctx, text, caretLine, nextLine)
  endif
enddef

export def Commands(): dict<func>
  return {
    'meow-inner-of-thing': (ctx: P.Ctx) => PendThing(ctx, St.PENDING_INNER),
    'meow-bounds-of-thing': (ctx: P.Ctx) => PendThing(ctx, St.PENDING_BOUNDS),
    'meow-beginning-of-thing': (ctx: P.Ctx) => PendThing(ctx, St.PENDING_BEGIN),
    'meow-end-of-thing': (ctx: P.Ctx) => PendThing(ctx, St.PENDING_END),
    'meow-block': Block,
    'meow-to-block': ToBlock,
    'meow-join': Join,
  }
enddef
