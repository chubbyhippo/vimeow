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

export def Clamp(value: number, minimum: number, maximum: number): number
  if value < minimum
    return minimum
  endif
  if value > maximum
    return maximum
  endif
  return value
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

export def RegexQuote(text: string): string
  return substitute(text, '[\^\$\.\*\~\[\]\\/]', '\\&', 'g')
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
  var linesSeen = 0
  var i = 0
  var length = len(text)
  while i < length
    if text[i] == "\n"
      linesSeen += 1
      if linesSeen == line
        return i + 1
      endif
    endif
    i += 1
  endwhile
  return length
enddef

export def LineEnd(text: string, line: number): number
  var start = LineStart(text, line)
  var newline = stridx(text, "\n", start)
  if newline < 0
    return len(text)
  endif
  if newline > start && text[newline - 1] == "\r"
    return newline - 1
  endif
  return newline
enddef

export def IsBlankLine(text: string, line: number): bool
  return Slice(text, LineStart(text, line), LineEnd(text, line)) =~ '^\s*$'
enddef

def IsWordChar(char: string): bool
  if char == ''
    return false
  endif
  return char2nr(char) >= 128 || char =~ '^\w$'
enddef

export def IsSymbolChar(char: string): bool
  return IsWordChar(char) || char == '_' || char == '$'
enddef

export def CharPred(symbol: bool): func(string): bool
  return symbol ? IsSymbolChar : IsWordChar
enddef

def IsSpaceChar(char: string): bool
  return char != '' && char =~ '^\s$'
enddef

def IndexOfChar(text: string, char: string, from: number): number
  var i = from < 0 ? 0 : from
  var length = len(text)
  while i < length
    if text[i] == char
      return i
    endif
    i += 1
  endwhile
  return -1
enddef

def LastIndexOfChar(text: string, char: string, from: number): number
  var i = from > len(text) - 1 ? len(text) - 1 : from
  while i >= 0
    if text[i] == char
      return i
    endif
    i -= 1
  endwhile
  return -1
enddef

export def NthCharTarget(
    text: string, char: string, caret: number, count: number,
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
  for _ in range(count)
    found = backward ? LastIndexOfChar(text, char, from) : IndexOfChar(text, char, from)
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

def IsSentenceEnder(char: string): bool
  return char != '' && stridx(SENTENCE_ENDERS, char) >= 0
enddef

export def NextSentenceEnd(text: string, from: number, count: number): number
  var i = Clamp(from, 0, len(text))
  var last = len(text)
  for _ in range(count)
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

export def PrevSentenceStart(text: string, from: number, count: number): number
  var IsGap = (char: string): bool => IsSpaceChar(char) || IsSentenceEnder(char)
  var i = Clamp(from, 0, len(text))
  for _ in range(count)
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

def FollowingLineStart(text: string, lineStartOffset: number): number
  var i = lineStartOffset
  var length = len(text)
  while i < length && text[i] != "\n"
    i += 1
  endwhile
  return i < length ? i + 1 : i
enddef

def BlankLineAt(text: string, lineStartOffset: number): bool
  var i = lineStartOffset
  var length = len(text)
  while i < length && text[i] != "\n"
    if !IsSpaceChar(CharAt(text, i))
      return false
    endif
    i += 1
  endwhile
  return true
enddef

export def NextParagraphEnd(text: string, from: number, count: number): number
  var pos = Clamp(from, 0, len(text))
  var last = len(text)
  for _ in range(count)
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

export def PrevParagraphStart(text: string, from: number, count: number): number
  var pos = Clamp(from, 0, len(text))
  for _ in range(count)
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

export def WordsNextEnd(
    text: string, from: number, count: number, IsWord: func(string): bool): number
  var i = Clamp(from, 0, len(text))
  var last = len(text)
  for _ in range(count)
    while i < last && !IsWord(CharAt(text, i))
      i += 1
    endwhile
    while i < last && IsWord(CharAt(text, i))
      i += 1
    endwhile
  endfor
  return i
enddef

export def WordsPrevStart(
    text: string, from: number, count: number, IsWord: func(string): bool): number
  var i = Clamp(from, 0, len(text))
  for _ in range(count)
    while i > 0 && !IsWord(CharAt(text, i - 1))
      i -= 1
    endwhile
    while i > 0 && IsWord(CharAt(text, i - 1))
      i -= 1
    endwhile
  endfor
  return i
enddef

export def WordsMove(
    text: string, from: number, count: number, IsWord: func(string): bool): number
  if count >= 0
    return WordsNextEnd(text, from, count, IsWord)
  endif
  return WordsPrevStart(text, from, -count, IsWord)
enddef

export def WordsSpanAt(text: string, offset: number, IsWord: func(string): bool): list<number>
  var start = offset
  var end = offset
  var last = len(text)
  while start > 0 && IsWord(CharAt(text, start - 1))
    start -= 1
  endwhile
  while end < last && IsWord(CharAt(text, end))
    end += 1
  endwhile
  return [start, end]
enddef

def OffsetInWord(text: string, offset: number, IsWord: func(string): bool): number
  var last = len(text)
  if offset < last && IsWord(CharAt(text, offset))
    return offset
  endif
  if offset > 0 && IsWord(CharAt(text, offset - 1))
    return offset - 1
  endif
  var scan = offset
  while scan < last && !IsWord(CharAt(text, scan))
    scan += 1
  endwhile
  return scan < last ? scan : -1
enddef

export def WordsBoundsAt(text: string, offset: number, IsWord: func(string): bool): list<number>
  var inWord = OffsetInWord(text, offset, IsWord)
  if inWord < 0
    return []
  endif
  return WordsSpanAt(text, inWord, IsWord)
enddef

export def WordsFixSelectionMark(
    text: string, pos: number, mark: number, IsWord: func(string): bool): number
  var probeMax = len(text) - 1 < 0 ? 0 : len(text) - 1
  var probe = Clamp(mark > pos ? pos : pos - 1, 0, probeMax)
  var bounds = WordsBoundsAt(text, probe, IsWord)
  if empty(bounds)
    return mark
  endif
  if mark > pos
    return mark < bounds[1] ? mark : bounds[1]
  endif
  return mark > bounds[0] ? mark : bounds[0]
enddef

export def IsBlank(char: string): bool
  return char == ' ' || char == "\t"
enddef

export def FirstNonBlankOffset(text: string, from: number, stop: number): number
  var at = from
  while at < stop && IsBlank(CharAt(text, at))
    at += 1
  endwhile
  return at
enddef
