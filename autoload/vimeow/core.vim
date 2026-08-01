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

import autoload 'vimeow/core/registry.vim' as Registry
import autoload 'vimeow/core/motions.vim' as Motions
import autoload 'vimeow/core/selections.vim' as Selections
import autoload 'vimeow/core/search.vim' as Search
import autoload 'vimeow/core/structures.vim' as Structures
import autoload 'vimeow/core/grab.vim' as Grab
import autoload 'vimeow/core/edits.vim' as Edits
import autoload 'vimeow/core/avy.vim' as Avy
import autoload 'vimeow/core/view.vim' as View

var registered = false

export def Init()
  if registered
    return
  endif
  registered = true
  Registry.Register(Motions.Commands())
  Registry.Register(Selections.Commands())
  Registry.Register(Search.Commands())
  Registry.Register(Structures.Commands())
  Registry.Register(Grab.Commands())
  Registry.Register(Edits.Commands())
  Registry.Register(Avy.Commands())
  Registry.Register(View.Commands())
enddef
