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

const MAX_DISPATCH_DEPTH = 8

const LIST_MOTIONS = {
  'meow-next': 'vimeow.tree.focusDown',
  'meow-prev': 'vimeow.tree.focusUp',
  'meow-left': 'vimeow.tree.collapse',
  'meow-right': 'vimeow.tree.expand',
}

def MotionBinding(char: string, noremap: bool): dict<any>
  var binding: dict<any> = {}
  if !noremap
    binding = get(Rc.Cfg().motion, char, {})
  endif
  if empty(binding)
    binding = get(Rc.Defaults().motion, char, {})
  endif
  return binding
enddef

export def BoundChars(): dict<bool>
  var out: dict<bool> = {}
  var Consider = (char: string) => {
    var binding = MotionBinding(char, false)
    if !empty(binding) && get(binding, 'command', '') != 'ignore'
      out[char] = true
    endif
  }
  for char in keys(Rc.Defaults().motion)
    Consider(char)
  endfor
  for char in keys(Rc.Cfg().motion)
    Consider(char)
  endfor
  return out
enddef

export def Dispatch(Run: func(string), char: string, noremap: bool = false, depth: number = 0)
  var binding = MotionBinding(char, noremap)
  if empty(binding)
    return
  endif
  var command = get(binding, 'command', '')
  if command != ''
    if has_key(LIST_MOTIONS, command)
      Run(LIST_MOTIONS[command])
    endif
    return
  endif
  var action = get(binding, 'action', '')
  if action != ''
    Run(action)
    return
  endif
  var keys = get(binding, 'keys', '')
  if keys == '' || depth >= MAX_DISPATCH_DEPTH
    return
  endif
  for i in range(len(keys))
    Dispatch(Run, keys[i], noremap || !get(binding, 'recursive', false), depth + 1)
  endfor
enddef
