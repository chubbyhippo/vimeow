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

if exists('g:loaded_vimeow') || &compatible
  finish
endif
g:loaded_vimeow = 1

if !has('vim9script') || !has('textprop') || !has('popupwin')
  echomsg 'vimeow needs a Vim with +vim9script +textprop +popupwin'
  finish
endif

import autoload 'vimeow.vim' as Vimeow
import autoload 'vimeow/adapter.vim' as Adapter

Vimeow.Setup()

command! Vimeow          Adapter.Attach(bufnr('%'))
command! VimeowEditRc    Vimeow.EditRc()
command! VimeowReloadRc  Vimeow.ReloadRc()
command! VimeowAceWindow      Vimeow.AceWindow()
command! VimeowAceSwapWindow  Vimeow.AceSwapWindow()
command! VimeowAceResize      Vimeow.AceResize()

for [suffix, dir] in items({Left: 'left', Right: 'right', Up: 'up', Down: 'down'})
  execute printf('command! VimeowWindmove%s     Vimeow.WindmoveStep(%s)', suffix, string(dir))
  execute printf('command! VimeowWindmoveSwap%s Vimeow.WindmoveSwap(%s)', suffix, string(dir))
endfor

augroup vimeow
  autocmd!
  autocmd BufWinEnter * Vimeow.OnBufWinEnter()
  autocmd WinEnter    * Vimeow.OnWinEnter()
augroup END
