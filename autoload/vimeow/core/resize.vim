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
import autoload 'vimeow/core/rc.vim' as Rc
import autoload 'vimeow/core/engine.vim' as Engine

export def Keys(): list<string>
  return Rc.ResizeOrder()
enddef

export def BindingFor(key: string): dict<any>
  return get(Rc.ResizeBindings(), key, {})
enddef

export def Dispatch(ctx: P.Ctx, key: string): bool
  var binding = BindingFor(key)
  if empty(binding)
    return false
  endif
  Engine.RunBinding(ctx, binding)
  return true
enddef
