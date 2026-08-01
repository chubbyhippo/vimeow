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

def Pair(text: string, offset: number, open: string, close: string, inner: bool): dict<number>
  var depth = 0
  var start = -1
  var i = offset - 1
  while i >= 0
    var c = T.CharAt(text, i)
    if c == close
      depth += 1
    elseif c == open
      if depth == 0
        start = i
        break
      endif
      depth -= 1
    endif
    i -= 1
  endwhile
  if start < 0
    return {}
  endif
  depth = 0
  var stop = -1
  var j = offset
  var n = len(text)
  while j < n
    var c = T.CharAt(text, j)
    if c == open && j != start
      depth += 1
    elseif c == close
      if depth == 0
        stop = j
        break
      endif
      depth -= 1
    endif
    j += 1
  endwhile
  if stop < 0
    return {}
  endif
  if inner
    return {start: start + 1, stop: stop}
  endif
  return {start: start, stop: stop + 1}
enddef

def StringThing(text: string, offset: number, inner: bool): dict<number>
  var n = len(text)
  var i = 0
  while i < n
    var c = T.CharAt(text, i)
    if c == '"' || c == "'" || c == '`'
      var triple = i + 2 < n && T.CharAt(text, i + 1) == c && T.CharAt(text, i + 2) == c
      var width = triple ? 3 : 1
      var open = i
      var j = i + width
      var closeEnd = -1
      while j < n
        var d = T.CharAt(text, j)
        if !triple && d == "\n"
          break
        endif
        if d == '\'
          j += 2
        else
          var closes = true
          if triple
            closes = j + 2 < n && T.CharAt(text, j + 1) == c && T.CharAt(text, j + 2) == c
          endif
          if d == c && closes
            closeEnd = j + width
            break
          endif
          j += 1
        endif
      endwhile
      if closeEnd < 0
        i = open + width
      else
        if offset >= open && offset < closeEnd
          if inner
            return {start: open + width, stop: closeEnd - width}
          endif
          return {start: open, stop: closeEnd}
        endif
        i = closeEnd
      endif
    else
      i += 1
    endif
  endwhile
  return {}
enddef

def Symbol(text: string, offset: number): dict<number>
  var o = offset
  var n = len(text)
  if o >= n || !T.IsSymbolChar(T.CharAt(text, o))
    if o > 0 && T.IsSymbolChar(T.CharAt(text, o - 1))
      o -= 1
    else
      return {}
    endif
  endif
  var s = o
  var e = o
  while s > 0 && T.IsSymbolChar(T.CharAt(text, s - 1))
    s -= 1
  endwhile
  while e < n && T.IsSymbolChar(T.CharAt(text, e))
    e += 1
  endwhile
  return {start: s, stop: e}
enddef

def Window(ctx: P.Ctx, text: string): dict<number>
  var vis = ctx.port.VisibleLineRange()
  var last = T.LineCount(text) - 1
  var maxLine = max([last, 0])
  var first = T.Clamp(vis == null_object ? 0 : vis.first, 0, maxLine)
  var stop = T.Clamp(vis == null_object ? last : vis.last, 0, maxLine)
  return {start: T.LineStart(text, first), stop: T.LineEnd(text, stop)}
enddef

def Paragraph(text: string, offset: number, inner: bool): dict<number>
  if len(text) == 0
    return {}
  endif
  var count = T.LineCount(text)
  var ln = T.LineOfOffset(text, T.Clamp(offset, 0, len(text)))
  if T.IsBlankLine(text, ln)
    return {}
  endif
  var first = ln
  var last = ln
  while first > 0 && !T.IsBlankLine(text, first - 1)
    first -= 1
  endwhile
  while last < count - 1 && !T.IsBlankLine(text, last + 1)
    last += 1
  endwhile
  var start = T.LineStart(text, first)
  if inner
    return {start: start, stop: T.LineEnd(text, last)}
  endif
  var stop = last
  while stop < count - 1 && T.IsBlankLine(text, stop + 1)
    stop += 1
  endwhile
  var e = stop < count - 1 ? T.LineStart(text, stop + 1) : T.LineEnd(text, stop)
  return {start: start, stop: e}
enddef

def Line(text: string, offset: number, inner: bool): dict<number>
  var ln = T.LineOfOffset(text, T.Clamp(offset, 0, len(text)))
  if inner
    return {start: T.LineStart(text, ln), stop: T.LineEnd(text, ln)}
  endif
  return {start: T.LineStart(text, ln), stop: T.LineStart(text, ln + 1)}
enddef

def Defun(ctx: P.Ctx, text: string, offset: number): dict<number>
  var fromHost = ctx.port.SymbolRangeAt(offset)
  if fromHost != null_object
    return {start: fromHost.start, stop: fromHost.end}
  endif
  var b = Pair(text, offset, '{', '}', false)
  if empty(b)
    return {}
  endif
  while true
    var outer = Pair(text, b.start, '{', '}', false)
    if empty(outer)
      break
    endif
    b = outer
  endwhile
  return b
enddef

def IsEnder(c: string): bool
  return c != '' && stridx(T.SENTENCE_ENDERS, c) >= 0
enddef

def Sentence(text: string, offset: number, inner: bool): dict<number>
  var n = len(text)
  if n == 0
    return {}
  endif
  var s = T.Clamp(offset, 0, n - 1)
  while s > 0
    var c = T.CharAt(text, s - 1)
    if IsEnder(c) || (c == "\n" && s > 1 && T.CharAt(text, s - 2) == "\n")
      break
    endif
    s -= 1
  endwhile
  while s < n && T.CharAt(text, s) =~ '^\s$'
    s += 1
  endwhile
  var e = T.Clamp(offset, 0, n)
  while e < n && !IsEnder(T.CharAt(text, e))
      && !(T.CharAt(text, e) == "\n" && e + 1 < n && T.CharAt(text, e + 1) == "\n")
    e += 1
  endwhile
  if e < n && IsEnder(T.CharAt(text, e))
    e += 1
  endif
  if e <= s
    return {}
  endif
  if inner
    return {start: s, stop: e}
  endif
  var be = e
  while be < n && T.CharAt(text, be) == ' '
    be += 1
  endwhile
  return {start: s, stop: be}
enddef

def Compute(ctx: P.Ctx, ch: string, offset: number, inner: bool): dict<number>
  var text = ctx.port.GetText()
  if ch == 'r'
    return Pair(text, offset, '(', ')', inner)
  elseif ch == 's'
    return Pair(text, offset, '[', ']', inner)
  elseif ch == 'c'
    return Pair(text, offset, '{', '}', inner)
  elseif ch == 'g'
    return StringThing(text, offset, inner)
  elseif ch == 'e'
    return Symbol(text, offset)
  elseif ch == 'w'
    return Window(ctx, text)
  elseif ch == 'b'
    return {start: 0, stop: len(text)}
  elseif ch == 'p'
    return Paragraph(text, offset, inner)
  elseif ch == 'l'
    return Line(text, offset, inner)
  elseif ch == 'v'
    return Line(text, offset, true)
  elseif ch == 'd'
    return Defun(ctx, text, offset)
  elseif ch == '.'
    return Sentence(text, offset, inner)
  endif
  return {}
enddef

export def Inner(ctx: P.Ctx, ch: string, offset: number): dict<number>
  return Compute(ctx, ch, offset, true)
enddef

export def Bounds(ctx: P.Ctx, ch: string, offset: number): dict<number>
  return Compute(ctx, ch, offset, false)
enddef
