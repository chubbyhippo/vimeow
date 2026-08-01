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
import autoload 'vimeow/core/regex.vim' as Rx

const SEARCH_RING_LIMIT = 50

export def Push(st: St.MeowState, pattern: string)
  var kept: list<string> = []
  for p in st.searchHistory
    if p != pattern
      add(kept, p)
    endif
  endfor
  add(kept, pattern)
  while len(kept) > SEARCH_RING_LIMIT
    remove(kept, 0)
  endwhile
  st.searchHistory = kept
enddef

def SearchWith(ctx: P.Ctx, pattern: string, backward: bool)
  var text = ctx.port.GetText()
  var caret = Sel.Primary(ctx).active
  var matches = Rx.AllMatches(pattern, text)
  var m: dict<number> = {}
  if !backward
    for x in matches
      if x.start >= caret
        m = x
        break
      endif
    endfor
    if empty(m) && !empty(matches)
      m = matches[0]
    endif
  else
    for x in matches
      if x.stop <= caret
        m = x
      endif
    endfor
    if empty(m) && !empty(matches)
      m = matches[-1]
    endif
  endif
  if empty(m)
    ctx.ui.Hint('No match: ' .. pattern)
    return
  endif
  if !backward
    Sel.Select(ctx, St.SEL_VISIT, m.start, m.stop, false)
  else
    Sel.Select(ctx, St.SEL_VISIT, m.stop, m.start, false)
  endif
enddef

def Search(ctx: P.Ctx)
  var st = ctx.st
  var sel = Sel.Primary(ctx)
  var pattern = empty(st.searchHistory) ? '' : st.searchHistory[-1]
  if Sel.HasSelection(sel)
    var selText = T.Slice(ctx.port.GetText(), sel.Lo(), sel.Hi())
    if len(selText) > 0 && (pattern == '' || !Rx.FullyMatches(pattern, selText))
      pattern = T.RegexQuote(selText)
      Push(st, pattern)
    endif
  endif
  if pattern == ''
    ctx.ui.Hint('No search pattern')
    return
  endif
  SearchWith(ctx, pattern, st.TakeCount(1) < 0 || Sel.BackwardP(ctx))
enddef

def Visit(ctx: P.Ctx)
  var backward = ctx.st.TakeCount(1) < 0
  var input = ctx.ui.Input('Visit (regexp):', '')
  if input == ''
    return
  endif
  var pattern = Rx.IsValid(input) ? input : T.RegexQuote(input)
  Push(ctx.st, pattern)
  SearchWith(ctx, pattern, backward)
enddef

export def Commands(): dict<func>
  return {
    'meow-search': Search,
    'meow-visit': Visit,
  }
enddef
