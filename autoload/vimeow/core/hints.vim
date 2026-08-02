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
  var state = ctx.state
  var caret = sel.active
  var backward = caret < sel.anchor
  var out: list<number> = []
  if state.selType == St.SEL_WORD || state.selType == St.SEL_SYMBOL
    var IsWord = T.CharPred(state.selType == St.SEL_SYMBOL)
    var i = caret
    for _ in range(count)
      i = backward ? T.WordsPrevStart(text, i, 1, IsWord) : T.WordsNextEnd(text, i, 1, IsWord)
      if backward && i <= 0
        break
      endif
      if !backward && i >= len(text)
        break
      endif
      add(out, i)
    endfor
  elseif state.selType == St.SEL_LINE
    var line = T.LineOfOffset(text, caret)
    for _ in range(count)
      line += backward ? -1 : 1
      if line < 0 || line > T.LineCount(text) - 1
        break
      endif
      add(out, backward ? T.LineStart(text, line) : T.LineEnd(text, line))
    endfor
  elseif state.selType == St.SEL_FIND || state.selType == St.SEL_TILL
    if empty(state.lastFind)
      return out
    endif
    var till = state.selType == St.SEL_TILL
    for nth in range(1, count)
      var target = T.NthCharTarget(text, state.lastFind.ch, caret, nth, backward, till)
      if target < 0
        break
      endif
      add(out, target)
    endfor
  endif
  var seen: dict<bool> = {}
  var unique: list<number> = []
  for position in out
    if !has_key(seen, string(position))
      seen[string(position)] = true
      add(unique, position)
    endif
  endfor
  return unique
enddef
