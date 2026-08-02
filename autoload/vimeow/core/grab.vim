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
  ctx.state.grab = {}
  ctx.ui.SetGrabHighlight(null_object)
enddef

def Set(ctx: P.Ctx, start: number, stop: number)
  ctx.state.grab = {start: start, stop: stop}
  if stop > start
    ctx.ui.SetGrabHighlight(P.OffsetRange.new(start, stop))
  else
    ctx.ui.SetGrabHighlight(null_object)
  endif
enddef

export def AdjustForEdits(state: St.MeowState, edits: list<P.TextEdit>)
  if empty(state.grab)
    return
  endif
  var grabbed = state.grab
  var sorted = copy(edits)
  sort(sorted, (a, b) => b.start - a.start)
  for edit in sorted
    var delta = len(edit.text) - (edit.end - edit.start)
    if grabbed.start >= edit.end
      grabbed.start += delta
      grabbed.stop += delta
    else
      if grabbed.stop >= edit.end
        grabbed.stop += delta
      elseif grabbed.stop > edit.start
        grabbed.stop = edit.start
      endif
      if grabbed.start > edit.start
        grabbed.start = edit.start
      endif
    endif
  endfor
  if grabbed.stop < grabbed.start
    grabbed.stop = grabbed.start
  endif
enddef

def DoGrab(ctx: P.Ctx)
  Clear(ctx)
  var sel = Sel.Primary(ctx)
  if Sel.HasSelection(sel)
    Set(ctx, sel.SelStart(), sel.SelEnd())
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
  Set(ctx, sel.SelStart(), sel.SelEnd())
  Sel.Cancel(ctx)
enddef

def Swap(ctx: P.Ctx)
  if Edits.BlockedReadOnly(ctx)
    return
  endif
  var port = ctx.port
  var state = ctx.state
  var sel = Sel.Primary(ctx)
  if empty(state.grab)
    ctx.ui.Hint('No grab')
    return
  endif
  if !Sel.HasSelection(sel)
    ctx.ui.Hint('meow-swap-grab needs a selection')
    return
  endif
  var grabStart = state.grab.start
  var grabEnd = state.grab.stop
  var selStart = sel.SelStart()
  var selEnd = sel.SelEnd()
  if max([grabStart, selStart]) < min([grabEnd, selEnd])
      && !(grabStart == selStart && grabEnd == selEnd)
    ctx.ui.Hint('Selection overlaps the grab')
    return
  endif
  var text = port.GetText()
  var grabText = T.Slice(text, grabStart, grabEnd)
  var selText = T.Slice(text, selStart, selEnd)
  state.grab = {}
  port.Edit([
    P.TextEdit.new(selStart, selEnd, grabText),
    P.TextEdit.new(grabStart, grabEnd, selText),
  ])
  if grabStart <= selStart
    var delta = len(selText) - (grabEnd - grabStart)
    Set(ctx, grabStart, grabStart + len(selText))
    var caret = selStart + delta + len(grabText)
    port.SetSelections([P.SelRange.new(caret, caret)])
  else
    var delta = len(grabText) - (selEnd - selStart)
    Set(ctx, grabStart + delta, grabStart + delta + len(selText))
    var caret = selStart + len(grabText)
    port.SetSelections([P.SelRange.new(caret, caret)])
  endif
  state.selType = St.SEL_NONE
enddef

export def Pop(ctx: P.Ctx): bool
  if empty(ctx.state.grab)
    return false
  endif
  var start = ctx.state.grab.start
  var stop = ctx.state.grab.stop
  Clear(ctx)
  Sel.Select(ctx, St.SEL_TRANSIENT, start, stop, false)
  return true
enddef

export def Beacon(ctx: P.Ctx)
  var port = ctx.port
  var state = ctx.state
  if empty(state.grab) || state.grab.stop <= state.grab.start
    return
  endif
  var grabStart = state.grab.start
  var grabEnd = state.grab.stop
  var sel = Sel.Primary(ctx)
  if !Sel.HasSelection(sel)
    return
  endif
  var selStart = sel.SelStart()
  var selEnd = sel.SelEnd()
  if selStart < grabStart || selEnd > grabEnd || selEnd == selStart
    return
  endif
  var text = port.GetText()
  var sels: list<P.SelRange> = []
  if index([St.SEL_WORD, St.SEL_SYMBOL, St.SEL_VISIT,
            St.SEL_FIND, St.SEL_TILL, St.SEL_CHAR], state.selType) >= 0
    var selText = T.Slice(text, selStart, selEnd)
    if selText =~ '^\s*$'
      return
    endif
    var bounded = state.selType == St.SEL_WORD || state.selType == St.SEL_SYMBOL
    var quoted = T.RegexQuote(selText)
    var pattern = bounded ? '\<' .. quoted .. '\>' : quoted
    var region = T.Slice(text, grabStart, grabEnd)
    var added = 0
    for match in Rx.AllMatches(pattern, region)
      var matchStart = grabStart + match.start
      var matchEnd = grabStart + match.stop
      if matchStart != selStart
        add(sels, P.SelRange.new(matchStart, matchEnd))
        added += 1
        if added >= MAX_GRAB_SYNC_MATCHES
          break
        endif
      endif
    endfor
    if empty(sels)
      return
    endif
    insert(sels, P.SelRange.new(selStart, selEnd), 0)
  elseif state.selType == St.SEL_LINE
    var first = T.LineOfOffset(text, grabStart)
    var last = T.LineOfOffset(text, max([grabEnd - 1, grabStart]))
    if last <= first
      return
    endif
    for line in range(first, last)
      add(sels, P.SelRange.new(T.LineStart(text, line), T.LineEnd(text, line)))
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
