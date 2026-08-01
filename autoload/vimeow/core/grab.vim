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
import autoload 'vimeow/core/edits.vim' as Edits
import autoload 'vimeow/core/regex.vim' as Rx

const MAX_GRAB_SYNC_MATCHES = 500

export def Clear(ctx: P.Ctx)
  ctx.st.grab = {}
  ctx.ui.SetGrabHighlight(null_object)
enddef

def Set(ctx: P.Ctx, start: number, stop: number)
  ctx.st.grab = {start: start, stop: stop}
  if stop > start
    ctx.ui.SetGrabHighlight(P.OffsetRange.new(start, stop))
  else
    ctx.ui.SetGrabHighlight(null_object)
  endif
enddef

export def AdjustForEdits(st: St.MeowState, edits: list<P.TextEdit>)
  if empty(st.grab)
    return
  endif
  var g = st.grab
  var sorted = copy(edits)
  sort(sorted, (a, b) => b.start - a.start)
  for e in sorted
    var delta = len(e.text) - (e.end - e.start)
    if g.start >= e.end
      g.start += delta
      g.stop += delta
    else
      if g.stop >= e.end
        g.stop += delta
      elseif g.stop > e.start
        g.stop = e.start
      endif
      if g.start > e.start
        g.start = e.start
      endif
    endif
  endfor
  if g.stop < g.start
    g.stop = g.start
  endif
enddef

def DoGrab(ctx: P.Ctx)
  Clear(ctx)
  var sel = Sel.Primary(ctx)
  if Sel.HasSelection(sel)
    Set(ctx, sel.Lo(), sel.Hi())
  endif
  Sel.Cancel(ctx)
enddef

def Sync(ctx: P.Ctx)
  var sel = Sel.Primary(ctx)
  if !Sel.HasSelection(sel)
    ctx.ui.Hint('meow-sync-grab needs a selection')
    return
  endif
  Clear(ctx)
  Set(ctx, sel.Lo(), sel.Hi())
  Sel.Cancel(ctx)
enddef

def Swap(ctx: P.Ctx)
  if Edits.BlockedReadOnly(ctx)
    return
  endif
  var port = ctx.port
  var st = ctx.st
  var sel = Sel.Primary(ctx)
  if empty(st.grab)
    ctx.ui.Hint('No grab')
    return
  endif
  if !Sel.HasSelection(sel)
    ctx.ui.Hint('meow-swap-grab needs a selection')
    return
  endif
  var gs = st.grab.start
  var ge = st.grab.stop
  var ss = sel.Lo()
  var se = sel.Hi()
  if max([gs, ss]) < min([ge, se]) && !(gs == ss && ge == se)
    ctx.ui.Hint('Selection overlaps the grab')
    return
  endif
  var text = port.GetText()
  var grabText = T.Slice(text, gs, ge)
  var selText = T.Slice(text, ss, se)
  st.grab = {}
  port.Edit([P.TextEdit.new(ss, se, grabText), P.TextEdit.new(gs, ge, selText)])
  if gs <= ss
    var delta = len(selText) - (ge - gs)
    Set(ctx, gs, gs + len(selText))
    var caret = ss + delta + len(grabText)
    port.SetSelections([P.SelRange.new(caret, caret)])
  else
    var delta = len(grabText) - (se - ss)
    Set(ctx, gs + delta, gs + delta + len(selText))
    var caret = ss + len(grabText)
    port.SetSelections([P.SelRange.new(caret, caret)])
  endif
  st.selType = St.SEL_NONE
enddef

export def Pop(ctx: P.Ctx): bool
  if empty(ctx.st.grab)
    return false
  endif
  var start = ctx.st.grab.start
  var stop = ctx.st.grab.stop
  Clear(ctx)
  Sel.Select(ctx, St.SEL_TRANSIENT, start, stop, false)
  return true
enddef

export def Beacon(ctx: P.Ctx)
  var port = ctx.port
  var st = ctx.st
  if empty(st.grab) || st.grab.stop <= st.grab.start
    return
  endif
  var gStart = st.grab.start
  var gStop = st.grab.stop
  var sel = Sel.Primary(ctx)
  if !Sel.HasSelection(sel)
    return
  endif
  var ss = sel.Lo()
  var se = sel.Hi()
  if ss < gStart || se > gStop || se == ss
    return
  endif
  var text = port.GetText()
  var sels: list<P.SelRange> = []
  if index([St.SEL_WORD, St.SEL_SYMBOL, St.SEL_VISIT,
            St.SEL_FIND, St.SEL_TILL, St.SEL_CHAR], st.selType) >= 0
    var selText = T.Slice(text, ss, se)
    if selText =~ '^\s*$'
      return
    endif
    var bounded = st.selType == St.SEL_WORD || st.selType == St.SEL_SYMBOL
    var quoted = T.RegexQuote(selText)
    var pattern = bounded ? '\<' .. quoted .. '\>' : quoted
    var region = T.Slice(text, gStart, gStop)
    var added = 0
    for m in Rx.AllMatches(pattern, region)
      var s0 = gStart + m.start
      var e0 = gStart + m.stop
      if s0 != ss
        add(sels, P.SelRange.new(s0, e0))
        added += 1
        if added >= MAX_GRAB_SYNC_MATCHES
          break
        endif
      endif
    endfor
    if empty(sels)
      return
    endif
    insert(sels, P.SelRange.new(ss, se), 0)
  elseif st.selType == St.SEL_LINE
    var first = T.LineOfOffset(text, gStart)
    var last = T.LineOfOffset(text, max([gStop - 1, gStart]))
    if last <= first
      return
    endif
    for ln in range(first, last)
      add(sels, P.SelRange.new(T.LineStart(text, ln), T.LineEnd(text, ln)))
    endfor
  else
    return
  endif
  port.SetSelections(sels)
enddef

export def Commands(): dict<func>
  return {
    'meow-grab': DoGrab,
    'meow-sync-grab': Sync,
    'meow-swap-grab': Swap,
  }
enddef
