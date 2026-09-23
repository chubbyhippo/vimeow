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
    var char = T.CharAt(text, i)
    if char == close
      depth += 1
    elseif char == open
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
  var length = len(text)
  while j < length
    var char = T.CharAt(text, j)
    if char == open && j != start
      depth += 1
    elseif char == close
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
  var length = len(text)
  var i = 0
  while i < length
    var quote = T.CharAt(text, i)
    if quote == '"' || quote == "'" || quote == '`'
      var triple = i + 2 < length
          && T.CharAt(text, i + 1) == quote && T.CharAt(text, i + 2) == quote
      var width = triple ? 3 : 1
      var open = i
      var j = i + width
      var closeEnd = -1
      while j < length
        var char = T.CharAt(text, j)
        if !triple && char == "\n"
          break
        endif
        if char == '\'
          j += 2
        else
          var closes = true
          if triple
            closes = j + 2 < length
                && T.CharAt(text, j + 1) == quote && T.CharAt(text, j + 2) == quote
          endif
          if char == quote && closes
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

def LineStartBefore(text: string, offset: number): number
  var i = offset - 1
  while i >= 0 && T.CharAt(text, i) != "\n"
    i -= 1
  endwhile
  return i + 1
enddef

def LineEndAfter(text: string, offset: number): number
  var length = len(text)
  var i = offset
  while i < length && T.CharAt(text, i) != "\n"
    i += 1
  endwhile
  return i
enddef

def ScanForwardToDelim(text: string, start: number, stop: number, delim: string): number
  var j = start
  while j < stop
    var char = T.CharAt(text, j)
    if char == '\'
      j += 2
    else
      if char == delim
        return j
      endif
      j += 1
    endif
  endwhile
  return -1
enddef

def IsEscapedAt(text: string, index: number, lineStart: number): bool
  var count = 0
  var j = index - 1
  while j >= lineStart && T.CharAt(text, j) == '\'
    count += 1
    j -= 1
  endwhile
  return count % 2 == 1
enddef

def ScanBackwardToDelim(text: string, start: number, lineStart: number, delim: string): number
  var i = start
  while i >= lineStart
    if T.CharAt(text, i) == delim && !IsEscapedAt(text, i, lineStart)
      return i
    endif
    i -= 1
  endwhile
  return -1
enddef

def Delimited(text: string, offset: number, delim: string, inner: bool): dict<number>
  var lineStart = LineStartBefore(text, offset)
  var lineEnd = LineEndAfter(text, offset)
  var open = ScanBackwardToDelim(text, offset - 1, lineStart, delim)
  if open < 0
    return {}
  endif
  var close = ScanForwardToDelim(text, max([offset, open + 1]), lineEnd, delim)
  if close < 0
    return {}
  endif
  if inner
    return {start: open + 1, stop: close}
  endif
  return {start: open, stop: close + 1}
enddef

def Symbol(text: string, offset: number): dict<number>
  var at = offset
  var length = len(text)
  if at >= length || !T.IsSymbolChar(T.CharAt(text, at))
    if at > 0 && T.IsSymbolChar(T.CharAt(text, at - 1))
      at -= 1
    else
      return {}
    endif
  endif
  var start = at
  var end = at
  while start > 0 && T.IsSymbolChar(T.CharAt(text, start - 1))
    start -= 1
  endwhile
  while end < length && T.IsSymbolChar(T.CharAt(text, end))
    end += 1
  endwhile
  return {start: start, stop: end}
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
  var caretLine = T.LineOfOffset(text, T.Clamp(offset, 0, len(text)))
  if T.IsBlankLine(text, caretLine)
    return {}
  endif
  var first = caretLine
  var last = caretLine
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
  var end = stop < count - 1 ? T.LineStart(text, stop + 1) : T.LineEnd(text, stop)
  return {start: start, stop: end}
enddef

def Line(text: string, offset: number, inner: bool): dict<number>
  var line = T.LineOfOffset(text, T.Clamp(offset, 0, len(text)))
  if inner
    return {start: T.LineStart(text, line), stop: T.LineEnd(text, line)}
  endif
  return {start: T.LineStart(text, line), stop: T.LineStart(text, line + 1)}
enddef

def Defun(ctx: P.Ctx, text: string, offset: number): dict<number>
  var fromHost = ctx.port.SymbolRangeAt(offset)
  if fromHost != null_object
    return {start: fromHost.start, stop: fromHost.end}
  endif
  var braces = Pair(text, offset, '{', '}', false)
  if empty(braces)
    return {}
  endif
  while true
    var outer = Pair(text, braces.start, '{', '}', false)
    if empty(outer)
      break
    endif
    braces = outer
  endwhile
  return braces
enddef

def IsEnder(char: string): bool
  return char != '' && stridx(T.SENTENCE_ENDERS, char) >= 0
enddef

def Sentence(text: string, offset: number, inner: bool): dict<number>
  var length = len(text)
  if length == 0
    return {}
  endif
  var start = T.Clamp(offset, 0, length - 1)
  while start > 0
    var char = T.CharAt(text, start - 1)
    if IsEnder(char) || (char == "\n" && start > 1 && T.CharAt(text, start - 2) == "\n")
      break
    endif
    start -= 1
  endwhile
  while start < length && T.CharAt(text, start) =~ '^\s$'
    start += 1
  endwhile
  var end = T.Clamp(offset, 0, length)
  while end < length && !IsEnder(T.CharAt(text, end))
      && !(T.CharAt(text, end) == "\n" && end + 1 < length && T.CharAt(text, end + 1) == "\n")
    end += 1
  endwhile
  if end < length && IsEnder(T.CharAt(text, end))
    end += 1
  endif
  if end <= start
    return {}
  endif
  if inner
    return {start: start, stop: end}
  endif
  var afterBlanks = end
  while afterBlanks < length && T.CharAt(text, afterBlanks) == ' '
    afterBlanks += 1
  endwhile
  return {start: start, stop: afterBlanks}
enddef

def Compute(ctx: P.Ctx, char: string, offset: number, inner: bool): dict<number>
  var text = ctx.port.GetText()
  if char == 'r'
    return Pair(text, offset, '(', ')', inner)
  elseif char == 's'
    return Pair(text, offset, '[', ']', inner)
  elseif char == 'c'
    return Pair(text, offset, '{', '}', inner)
  elseif char == 'g'
    return StringThing(text, offset, inner)
  elseif char == '/'
    return Delimited(text, offset, '/', inner)
  elseif char == '?'
    return Delimited(text, offset, '?', inner)
  elseif char == 'e'
    return Symbol(text, offset)
  elseif char == 'w'
    return Window(ctx, text)
  elseif char == 'b'
    return {start: 0, stop: len(text)}
  elseif char == 'p'
    return Paragraph(text, offset, inner)
  elseif char == 'l'
    return Line(text, offset, inner)
  elseif char == 'v'
    return Line(text, offset, true)
  elseif char == 'd'
    return Defun(ctx, text, offset)
  elseif char == '.'
    return Sentence(text, offset, inner)
  endif
  return {}
enddef

export def Inner(ctx: P.Ctx, char: string, offset: number): dict<number>
  return Compute(ctx, char, offset, true)
enddef

export def Bounds(ctx: P.Ctx, char: string, offset: number): dict<number>
  return Compute(ctx, char, offset, false)
enddef
