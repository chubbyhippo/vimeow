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

import autoload 'vimeow/core/rc.vim' as Rc

export const THINGS = [
  ['r', 'round ( )'],
  ['s', 'square [ ]'],
  ['c', 'curly { }'],
  ['g', 'string'],
  ['/', 'slash-delimited'],
  ['?', 'question-delimited'],
  ['e', 'symbol'],
  ['w', 'window'],
  ['b', 'buffer'],
  ['p', 'paragraph'],
  ['l', 'line'],
  ['v', 'visual line'],
  ['d', 'defun'],
  ['.', 'sentence'],
]

export def KeypadRows(buffer: string): list<list<string>>
  var descs = Rc.KeypadDescs()[0]
  var pair = Rc.Keypad()
  var bindings = pair[0]
  var order = pair[1]
  var rows: dict<string> = {}
  var rowOrder: list<string> = []
  for seq in order
    if strpart(seq, 0, len(buffer)) == buffer && seq != buffer
      var child = buffer .. strpart(seq, len(buffer), 1)
      var label = ''
      if seq == child
        label = get(descs, seq, '')
        if label == ''
          var binding = bindings[seq]
          label = get(binding, 'action', get(binding, 'command', get(binding, 'keys', '')))
        endif
      else
        label = get(descs, child, '+more')
      endif
      if !has_key(rows, child)
        add(rowOrder, child)
        rows[child] = label
      elseif has_key(descs, child)
        rows[child] = label
      endif
    endif
  endfor
  sort(rowOrder)
  var out: list<list<string>> = []
  for child in rowOrder
    var key = strpart(child, len(child) - 1)
    add(out, [key == ' ' ? 'SPC' : key, rows[child]])
  endfor
  return out
enddef
