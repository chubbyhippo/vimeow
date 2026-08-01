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
import autoload 'vimeow/core/port.vim' as P
import autoload 'vimeow/core/selections.vim' as Sel

const KEYS = 'asdfghjkl'

export const TIMEOUT_MS = 250

export def Subdiv(n: number, b: number): list<number>
  var p = 0
  var x1 = 1
  while x1 * b <= n
    x1 = x1 * b
    p += 1
  endwhile
  x1 = x1 / b
  if x1 < 1
    x1 = 1
  endif
  var x2 = b * x1
  var delta = n - x2
  var n2 = delta / (x2 - x1)
  var n1 = b - n2 - 1
  var out: list<number> = []
  for _ in range(n1)
    add(out, x1)
  endfor
  add(out, n - n1 * x1 - n2 * x2)
  for _ in range(n2)
    add(out, x2)
  endfor
  return out
enddef

def Tree(candidates: list<number>): dict<any>
  if len(candidates) < len(KEYS)
    var children: list<any> = []
    var i = 0
    for offset in candidates
      add(children, [KEYS[i], {kind: 'leaf', offset: offset}])
      i += 1
    endfor
    return {kind: 'branch', children: children}
  endif
  var rest = copy(candidates)
  var children: list<any> = []
  var i = 0
  for size in Subdiv(len(candidates), len(KEYS))
    var taken = rest[0 : size - 1]
    rest = rest[size :]
    if size == 1
      add(children, [KEYS[i], {kind: 'leaf', offset: taken[0]}])
    else
      add(children, [KEYS[i], Tree(taken)])
    endif
    i += 1
  endfor
  return {kind: 'branch', children: children}
enddef

def Labels(node: dict<any>): list<P.AvyLabel>
  var out: list<P.AvyLabel> = []
  def Walk(n: dict<any>, path: string)
    if n.kind == 'leaf'
      add(out, P.AvyLabel.new(n.offset, path))
    else
      for pair in n.children
        Walk(pair[1], path .. pair[0])
      endfor
    endif
  enddef
  Walk(node, '')
  return out
enddef

export def LabelsFor(count: number): list<string>
  if count <= 0
    return []
  endif
  var indexed = Labels(Tree(range(count)))
  sort(indexed, (a, b) => a.offset - b.offset)
  var out: list<string> = []
  for l in indexed
    add(out, l.label)
  endfor
  return out
enddef

export def LabelsMatching(labelList: list<string>, input: string): list<string>
  var out: list<string> = []
  for l in labelList
    if strpart(l, 0, len(input)) == input
      add(out, l)
    endif
  endfor
  return out
enddef

def NewSession(gotoLine: bool): dict<any>
  return {phase: 'collecting', input: '', node: {}, timer: -1, gotoLine: gotoLine}
enddef

def VisibleLines(ctx: P.Ctx): dict<number>
  var total = T.LineCount(ctx.port.GetText())
  var visible = ctx.port.VisibleLineRange()
  if visible == null_object
    return {first: 0, last: total - 1}
  endif
  return {
    first: T.Clamp(visible.first, 0, total - 1),
    last: T.Clamp(visible.last, 0, total - 1),
  }
enddef

def Matches(ctx: P.Ctx, input: string): list<number>
  if len(input) == 0
    return []
  endif
  var text = ctx.port.GetText()
  var vis = VisibleLines(ctx)
  var from = T.LineStart(text, vis.first)
  var to = T.LineEnd(text, vis.last)
  var haystack = tolower(text)
  var needle = tolower(input)
  var out: list<number> = []
  var i = from
  while i <= to - len(needle)
    if strpart(haystack, i, len(needle)) == needle
      add(out, i)
      i += len(needle)
    else
      i += 1
    endif
  endwhile
  return out
enddef

def Jump(ctx: P.Ctx, offset: number)
  var sel = ctx.port.GetSelections()[0]
  if sel.anchor != sel.active
    ctx.port.SetSelections([P.SelRange.new(Sel.Mark(ctx), offset)])
  else
    ctx.port.SetSelections([P.SelRange.new(offset, offset)])
  endif
enddef

export def Cancel(ctx: P.Ctx)
  var session = ctx.st.avy
  if !empty(session)
    if session.timer >= 0
      ctx.ui.CancelTimer(session.timer)
    endif
    session.timer = -1
    ctx.ui.ClearAvy()
  endif
  ctx.st.avy = {}
enddef

export def AwaitingTimeout(st: any): bool
  return !empty(st.avy) && st.avy.phase == 'collecting' && st.avy.input != ''
enddef

def ToSelecting(ctx: P.Ctx, session: dict<any>, candidates: list<number>)
  ctx.ui.ClearAvy()
  session.phase = 'selecting'
  session.node = Tree(candidates)
  ctx.ui.ShowAvyLabels(Labels(session.node))
enddef

export def FinishInput(ctx: P.Ctx)
  var session = ctx.st.avy
  if empty(session) || session.phase != 'collecting'
    return
  endif
  if session.timer >= 0
    ctx.ui.CancelTimer(session.timer)
  endif
  session.timer = -1
  var candidates = Matches(ctx, session.input)
  if empty(candidates)
    Cancel(ctx)
    ctx.ui.Hint('zero candidates')
  elseif len(candidates) == 1
    Cancel(ctx)
    Jump(ctx, candidates[0])
  else
    ToSelecting(ctx, session, candidates)
  endif
enddef

def Collect(ctx: P.Ctx, session: dict<any>, c: string)
  session.input = session.input .. c
  if session.timer >= 0
    ctx.ui.CancelTimer(session.timer)
  endif
  session.timer = ctx.ui.StartTimer(TIMEOUT_MS, () => FinishInput(ctx))
  var width = len(session.input)
  var ranges: list<P.OffsetRange> = []
  for start in Matches(ctx, session.input)
    add(ranges, P.OffsetRange.new(start, start + width))
  endfor
  ctx.ui.ShowAvyMatches(ranges)
enddef

def SelectLabel(ctx: P.Ctx, session: dict<any>, c: string)
  if session.gotoLine && c >= '0' && c <= '9'
    Cancel(ctx)
    var input = ctx.ui.Input('Goto line:', c)
    if input == ''
      return
    endif
    var text = ctx.port.GetText()
    var ln = T.ParsedLineNumber(input, T.LineCount(text))
    if ln < 0
      return
    endif
    Jump(ctx, T.LineStart(text, ln))
    return
  endif
  var node = session.node
  if empty(node)
    return
  endif
  var child: dict<any> = {}
  for pair in node.children
    if pair[0] == c
      child = pair[1]
      break
    endif
  endfor
  if empty(child)
    ctx.ui.Hint('No such candidate: ' .. c)
  elseif child.kind == 'leaf'
    Cancel(ctx)
    Jump(ctx, child.offset)
  else
    session.node = child
    ctx.ui.ShowAvyLabels(Labels(child))
  endif
enddef

export def Key(ctx: P.Ctx, c: string)
  var session = ctx.st.avy
  if empty(session)
    return
  endif
  if session.phase == 'collecting'
    Collect(ctx, session, c)
  else
    SelectLabel(ctx, session, c)
  endif
enddef

def StartCharTimer(ctx: P.Ctx)
  Cancel(ctx)
  ctx.st.avy = NewSession(false)
enddef

def StartGotoLine(ctx: P.Ctx)
  Cancel(ctx)
  var session = NewSession(true)
  ctx.st.avy = session
  var text = ctx.port.GetText()
  var vis = VisibleLines(ctx)
  var candidates: list<number> = []
  for ln in range(vis.first, vis.last)
    add(candidates, T.LineStart(text, ln))
  endfor
  ToSelecting(ctx, session, candidates)
enddef

export def Commands(): dict<func>
  return {
    'avy-goto-char-timer': StartCharTimer,
    'avy-goto-line': StartGotoLine,
  }
enddef
