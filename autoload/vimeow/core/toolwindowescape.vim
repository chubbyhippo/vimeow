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


export const TIMEOUT_MS = 500

var lastSurface: string = ''
var lastAt: number = 0

export def Reset()
  lastSurface = ''
  lastAt = 0
enddef

export def OnEscape(surface: string, at: number): bool
  var doubled = surface != '' && surface == lastSurface && at - lastAt <= TIMEOUT_MS
  if doubled
    Reset()
    return true
  endif
  lastSurface = surface
  lastAt = at
  return false
enddef
