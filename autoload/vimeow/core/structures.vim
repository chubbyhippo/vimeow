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

def PendThing(ctx: P.Ctx, p: string)
  ctx.st.pending = p
  ctx.ui.ScheduleWhichKey('things', '')
enddef

export def ThingSelect(ctx: P.Ctx, kind: string, ch: string)
  var off = Sel.Primary(ctx).active
  var b = kind == St.PENDING_BOUNDS ? Things.Bounds(ctx, ch, off) : Things.Inner(ctx, ch, off)
  if empty(b)
    ctx.ui.Hint("No thing '" .. ch .. "' here")
    return
  endif
  if kind == St.PENDING_INNER
    Sel.Select(ctx, St.SEL_TRANSIENT, b.start, b.stop, false)
  elseif kind == St.PENDING_BOUNDS
    Sel.Select(ctx, St.SEL_TRANSIENT, b.stop, b.start, false)
  elseif kind == St.PENDING_BEGIN
    Sel.Select(ctx, St.SEL_TRANSIENT, off, b.start, false)
  elseif kind == St.PENDING_END
    Sel.Select(ctx, St.SEL_TRANSIENT, off, b.stop, false)
  endif
enddef

def EnclosingPair(text: string, s: number, e: number): dict<number>
  var stack: list<number> = []
  var best: dict<number> = {}
  var i = 0
  var n = len(text)
  while i < n
    var c = T.CharAt(text, i)
    if c == '"' || c == "'" || c == '`'
      var j = i + 1
      while j < n && T.CharAt(text, j) != c && T.CharAt(text, j) != "\n"
        if T.CharAt(text, j) == '\'
          j += 1
        endif
        j += 1
      endwhile
      i = (j < n && T.CharAt(text, j) == c) ? j + 1 : i + 1
    else
      if stridx(OPENS, c) >= 0
        add(stack, i)
      elseif stridx(CLOSES, c) >= 0
        var kind = stridx(CLOSES, c)
        while !empty(stack)
          var o = remove(stack, -1)
          if stridx(OPENS, T.CharAt(text, o)) == kind
            if o < s && i + 1 >= e && (empty(best) || i - o < best.close - best.open)
              best = {open: o, close: i}
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
  var active = ctx.st.selType == St.SEL_BLOCK && Sel.HasSelection(sel)
  var back = Sel.BackwardP(ctx) != (ctx.st.TakeCount(1) < 0)
  var s = active ? sel.Lo() : sel.active
  var e = active ? sel.Hi() : sel.active
  var p = EnclosingPair(text, s, e)
  if empty(p)
    ctx.ui.Hint('No enclosing block')
    return
  endif
  if back
    Sel.Select(ctx, St.SEL_BLOCK, p.close + 1, p.open, true)
  else
    Sel.Select(ctx, St.SEL_BLOCK, p.open, p.close + 1, true)
  endif
enddef

def ToBlock(ctx: P.Ctx)
  var text = ctx.port.GetText()
  var back = (ctx.st.selType == St.SEL_BLOCK && Sel.BackwardP(ctx)) || ctx.st.TakeCount(1) < 0
  var caret = Sel.Primary(ctx).active
  var p = EnclosingPair(text, caret, caret)
  if empty(p)
    ctx.ui.Hint('No enclosing block')
    return
  endif
  Sel.Select(ctx, St.SEL_BLOCK, caret, back ? p.open : p.close + 1, true)
enddef

def SelectJoin(ctx: P.Ctx, text: string, markLine: number, pointLine: number)
  var mark = T.LineEnd(text, markLine)
  var point = T.LineStart(text, pointLine)
  var eol = T.LineEnd(text, pointLine)
  while point < eol && T.CharAt(text, point) =~ '^\s$'
    point += 1
  endwhile
  Sel.Select(ctx, St.SEL_JOIN, mark, point, true)
enddef

def Join(ctx: P.Ctx)
  var text = ctx.port.GetText()
  if len(text) == 0
    return
  endif
  var n = ctx.st.TakeCount(1)
  var ln = T.LineOfOffset(text, Sel.Primary(ctx).active)
  if n >= 0
    var pl = ln - 1
    while pl >= 0 && T.IsBlankLine(text, pl)
      pl -= 1
    endwhile
    if pl < 0
      return
    endif
    SelectJoin(ctx, text, pl, ln)
  else
    var last = T.LineCount(text) - 1
    var nl = ln + 1
    while nl <= last && T.IsBlankLine(text, nl)
      nl += 1
    endwhile
    if nl > last
      return
    endif
    SelectJoin(ctx, text, ln, nl)
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
