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

import autoload 'vimeow/core/port.vim' as P

export var COMMANDS: dict<func> = {}

export def Register(commands: dict<func>)
  for [name, Fn] in items(commands)
    COMMANDS[name] = Fn
  endfor
enddef

export def Has(name: string): bool
  return has_key(COMMANDS, name)
enddef

export def Names(): list<string>
  return sort(keys(COMMANDS))
enddef

Register({
  'meow-negative-argument': (ctx: P.Ctx) => {
    ctx.st.negative = true
  },
  'negative-argument': (ctx: P.Ctx) => {
    ctx.st.negative = true
  },
  'meow-quit': (ctx: P.Ctx) => {
    ctx.port.CloseEditor()
  },
  'ignore': (ctx: P.Ctx) => {
  },
})
