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

export def ExpandHintPositions(ctx: P.Ctx, count: number = 10): list<number>
  var text = ctx.port.GetText()
  var sel = ctx.port.GetSelections()[0]
  if sel.anchor == sel.active
    return []
  endif
  var st = ctx.st
  var caret = sel.active
  var backward = caret < sel.anchor
  var out: list<number> = []
  if st.selType == St.SEL_WORD || st.selType == St.SEL_SYMBOL
    var Pred = T.CharPred(st.selType == St.SEL_SYMBOL)
    var i = caret
    for _ in range(count)
      i = backward ? T.WordsPrevStart(text, i, 1, Pred) : T.WordsNextEnd(text, i, 1, Pred)
      if backward && i <= 0
        break
      endif
      if !backward && i >= len(text)
        break
      endif
      add(out, i)
    endfor
  elseif st.selType == St.SEL_LINE
    var ln = T.LineOfOffset(text, caret)
    for _ in range(count)
      ln += backward ? -1 : 1
      if ln < 0 || ln > T.LineCount(text) - 1
        break
      endif
      add(out, backward ? T.LineStart(text, ln) : T.LineEnd(text, ln))
    endfor
  elseif st.selType == St.SEL_FIND || st.selType == St.SEL_TILL
    if empty(st.lastFind)
      return out
    endif
    var till = st.selType == St.SEL_TILL
    for k in range(1, count)
      var t = T.NthCharTarget(text, st.lastFind.ch, caret, k, backward, till)
      if t < 0
        break
      endif
      add(out, t)
    endfor
  endif
  var seen: dict<bool> = {}
  var unique: list<number> = []
  for p in out
    if !has_key(seen, string(p))
      seen[string(p)] = true
      add(unique, p)
    endif
  endfor
  return unique
enddef
