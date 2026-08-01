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

export def IsValid(pattern: string): bool
  try
    match('', pattern)
  catch
    return false
  endtry
  return true
enddef

export def AllMatches(pattern: string, text: string): list<dict<number>>
  if pattern == '' || !IsValid(pattern)
    return []
  endif
  var out: list<dict<number>> = []
  var from = 0
  var length = len(text)
  while from <= length
    var pos = matchstrpos(text, pattern, from)
    var s = pos[1]
    var e = pos[2]
    if s < 0
      break
    endif
    if e == s
      from = s + 1
      continue
    endif
    add(out, {start: s, stop: e})
    from = e
  endwhile
  return out
enddef

export def FullyMatches(pattern: string, s: string): bool
  if !IsValid(pattern)
    return false
  endif
  return match(s, '^\%(' .. pattern .. '\)$') >= 0
enddef
