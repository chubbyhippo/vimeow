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

export const SENTENCE_ENDERS = '.!?'

export def Clamp(n: number, lo: number, hi: number): number
  if n < lo
    return lo
  endif
  if n > hi
    return hi
  endif
  return n
enddef

export def CharAt(text: string, offset: number): string
  return strpart(text, offset, 1)
enddef

export def Slice(text: string, from: number, to: number = -1): string
  if to < 0
    return strpart(text, from)
  endif
  return strpart(text, from, to - from)
enddef

export def RegexQuote(s: string): string
  return substitute(s, '[\^\$\.\*\~\[\]\\/]', '\\&', 'g')
enddef

export def LineOfOffset(text: string, offset: number): number
  return count(strpart(text, 0, Clamp(offset, 0, len(text))), "\n")
enddef

export def LineCount(text: string): number
  return count(text, "\n") + 1
enddef

export def LineStart(text: string, line: number): number
  if line <= 0
    return 0
  endif
  var ln = 0
  var i = 0
  var n = len(text)
  while i < n
    if text[i] == "\n"
      ln += 1
      if ln == line
        return i + 1
      endif
    endif
    i += 1
  endwhile
  return n
enddef

export def LineEnd(text: string, line: number): number
  var s = LineStart(text, line)
  var nl = stridx(text, "\n", s)
  if nl < 0
    return len(text)
  endif
  if nl > s && text[nl - 1] == "\r"
    return nl - 1
  endif
  return nl
enddef

export def IsBlankLine(text: string, line: number): bool
  return Slice(text, LineStart(text, line), LineEnd(text, line)) =~ '^\s*$'
enddef

def IsWordChar(c: string): bool
  if c == ''
    return false
  endif
  return char2nr(c) >= 128 || c =~ '^\w$'
enddef

export def IsSymbolChar(c: string): bool
  return IsWordChar(c) || c == '_' || c == '$'
enddef

export def CharPred(symbol: bool): func(string): bool
  return symbol ? IsSymbolChar : IsWordChar
enddef

def IsSpaceChar(c: string): bool
  return c != '' && c =~ '^\s$'
enddef

def IndexOfChar(text: string, c: string, from: number): number
  var i = from < 0 ? 0 : from
  var n = len(text)
  while i < n
    if text[i] == c
      return i
    endif
    i += 1
  endwhile
  return -1
enddef

def LastIndexOfChar(text: string, c: string, from: number): number
  var i = from > len(text) - 1 ? len(text) - 1 : from
  while i >= 0
    if text[i] == c
      return i
    endif
    i -= 1
  endwhile
  return -1
enddef

export def NthCharTarget(
    text: string, ch: string, caret: number, n: number,
    backward: bool, till: bool): number
  var found = -1
  var from = 0
  if backward && till
    from = caret - 2
  elseif backward
    from = caret - 1
  elseif till
    from = caret + 1
  else
    from = caret
  endif
  for _ in range(n)
    found = backward ? LastIndexOfChar(text, ch, from) : IndexOfChar(text, ch, from)
    if found < 0
      return -1
    endif
    from = backward ? found - 1 : found + 1
  endfor
  if found < 0
    return -1
  endif
  if backward
    return till ? found + 1 : found
  endif
  return till ? found : found + 1
enddef

def IsSentenceEnder(c: string): bool
  return c != '' && stridx(SENTENCE_ENDERS, c) >= 0
enddef

export def NextSentenceEnd(text: string, from: number, n: number): number
  var i = Clamp(from, 0, len(text))
  var last = len(text)
  for _ in range(n)
    while i < last && !IsSentenceEnder(CharAt(text, i))
      i += 1
    endwhile
    while i < last && IsSentenceEnder(CharAt(text, i))
      i += 1
    endwhile
    while i < last && IsSpaceChar(CharAt(text, i))
      i += 1
    endwhile
  endfor
  return i
enddef

export def PrevSentenceStart(text: string, from: number, n: number): number
  var IsGap = (c: string): bool => IsSpaceChar(c) || IsSentenceEnder(c)
  var i = Clamp(from, 0, len(text))
  for _ in range(n)
    while i > 0 && IsGap(CharAt(text, i - 1))
      i -= 1
    endwhile
    while i > 0 && !IsGap(CharAt(text, i - 1))
      i -= 1
    endwhile
  endfor
  return i
enddef

def LineStartAt(text: string, offset: number): number
  var i = offset
  while i > 0 && text[i - 1] != "\n"
    i -= 1
  endwhile
  return i
enddef

def FollowingLineStart(text: string, bol: number): number
  var i = bol
  var n = len(text)
  while i < n && text[i] != "\n"
    i += 1
  endwhile
  return i < n ? i + 1 : i
enddef

def BlankLineAt(text: string, bol: number): bool
  var i = bol
  var n = len(text)
  while i < n && text[i] != "\n"
    if !IsSpaceChar(CharAt(text, i))
      return false
    endif
    i += 1
  endwhile
  return true
enddef

export def NextParagraphEnd(text: string, from: number, n: number): number
  var pos = Clamp(from, 0, len(text))
  var last = len(text)
  for _ in range(n)
    var i = LineStartAt(text, pos)
    while i < last && BlankLineAt(text, i)
      i = FollowingLineStart(text, i)
    endwhile
    while i < last && !BlankLineAt(text, i)
      i = FollowingLineStart(text, i)
    endwhile
    pos = i
  endfor
  return pos
enddef

def ParagraphStartBefore(text: string, offset: number): number
  var i = LineStartAt(text, offset)
  while i > 0 && BlankLineAt(text, i)
    i = LineStartAt(text, i - 1)
  endwhile
  while i > 0 && !BlankLineAt(text, LineStartAt(text, i - 1))
    i = LineStartAt(text, i - 1)
  endwhile
  var prevLineEmpty = i > 0 && text[i - 1] == "\n" && (i == 1 || text[i - 2] == "\n")
  return prevLineEmpty ? i - 1 : i
enddef

export def PrevParagraphStart(text: string, from: number, n: number): number
  var pos = Clamp(from, 0, len(text))
  for _ in range(n)
    if pos > 0
      var start = ParagraphStartBefore(text, pos)
      pos = start < pos ? start : ParagraphStartBefore(text, start - 1)
    endif
  endfor
  return pos
enddef

export def ParsedLineNumber(input: string, lineCount: number): number
  var digits = matchstr(input, '^\s*\zs-\?\d\+\ze\s*$')
  if digits == ''
    return -1
  endif
  var maxLine = lineCount - 1 < 0 ? 0 : lineCount - 1
  return Clamp(str2nr(digits) - 1, 0, maxLine)
enddef

export def WordsNextEnd(text: string, from: number, n: number, Pred: func(string): bool): number
  var i = Clamp(from, 0, len(text))
  var last = len(text)
  for _ in range(n)
    while i < last && !Pred(CharAt(text, i))
      i += 1
    endwhile
    while i < last && Pred(CharAt(text, i))
      i += 1
    endwhile
  endfor
  return i
enddef

export def WordsPrevStart(text: string, from: number, n: number, Pred: func(string): bool): number
  var i = Clamp(from, 0, len(text))
  for _ in range(n)
    while i > 0 && !Pred(CharAt(text, i - 1))
      i -= 1
    endwhile
    while i > 0 && Pred(CharAt(text, i - 1))
      i -= 1
    endwhile
  endfor
  return i
enddef

export def WordsMove(text: string, from: number, n: number, Pred: func(string): bool): number
  if n >= 0
    return WordsNextEnd(text, from, n, Pred)
  endif
  return WordsPrevStart(text, from, -n, Pred)
enddef

export def WordsSpanAt(text: string, offset: number, Pred: func(string): bool): list<number>
  var s = offset
  var e = offset
  var last = len(text)
  while s > 0 && Pred(CharAt(text, s - 1))
    s -= 1
  endwhile
  while e < last && Pred(CharAt(text, e))
    e += 1
  endwhile
  return [s, e]
enddef

export def WordsBoundsAt(text: string, offset: number, Pred: func(string): bool): list<number>
  var o = offset
  var last = len(text)
  if o >= last || !Pred(CharAt(text, o))
    if o > 0 && Pred(CharAt(text, o - 1))
      o -= 1
    else
      var f = o
      while f < last && !Pred(CharAt(text, f))
        f += 1
      endwhile
      if f >= last
        return []
      endif
      o = f
    endif
  endif
  return WordsSpanAt(text, o, Pred)
enddef

export def WordsFixSelectionMark(
    text: string, pos: number, mark: number, Pred: func(string): bool): number
  var probeMax = len(text) - 1 < 0 ? 0 : len(text) - 1
  var probe = Clamp(mark > pos ? pos : pos - 1, 0, probeMax)
  var bounds = WordsBoundsAt(text, probe, Pred)
  if empty(bounds)
    return mark
  endif
  if mark > pos
    return mark < bounds[1] ? mark : bounds[1]
  endif
  return mark > bounds[0] ? mark : bounds[0]
enddef

export def IsBlank(ch: string): bool
  return ch == ' ' || ch == "\t"
enddef
