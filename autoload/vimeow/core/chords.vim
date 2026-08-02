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

import autoload 'vimeow/core/chord.vim' as Chord
import autoload 'vimeow/core/state.vim' as St
import autoload 'vimeow/core/port.vim' as P
import autoload 'vimeow/core/rc.vim' as Rc
import autoload 'vimeow/core/engine.vim' as Engine

export def TakesChords(mode: string): bool
  return mode == St.NORMAL || mode == St.MOTION
enddef

export def BindingFor(chord: dict<any>): dict<any>
  if empty(chord)
    return {}
  endif
  return get(Rc.ChordBindings(), Chord.Spelling(chord), {})
enddef

export def Claims(mode: string, chord: dict<any>): bool
  return TakesChords(mode) && !empty(BindingFor(chord))
enddef

export def Dispatch(ctx: P.Ctx, chord: dict<any>): bool
  if !Claims(ctx.state.mode, chord)
    return false
  endif
  var binding = BindingFor(chord)
  if empty(binding)
    return false
  endif
  Engine.RunBinding(ctx, binding)
  return true
enddef
