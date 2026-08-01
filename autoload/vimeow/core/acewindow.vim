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

import autoload 'vimeow/core/avy.vim' as Avy

export const LABEL_THRESHOLD = 2

export const PLAN_NONE = 'none'
export const PLAN_OTHER = 'other'
export const PLAN_LABELS = 'labels'

export def Plan(windowCount: number): string
  if windowCount <= 1
    return PLAN_NONE
  endif
  if windowCount <= LABEL_THRESHOLD
    return PLAN_OTHER
  endif
  return PLAN_LABELS
enddef

export def Labels(windowCount: number): list<string>
  return Avy.LabelsFor(windowCount)
enddef

export def Matches(labelList: list<string>, input: string): list<string>
  return Avy.LabelsMatching(labelList, input)
enddef

export def Ordered(candidates: list<dict<any>>): list<any>
  var sorted = copy(candidates)
  sort(sorted, (a, b) => a.x != b.x ? a.x - b.x : a.y - b.y)
  var out: list<any> = []
  for c in sorted
    add(out, c.item)
  endfor
  return out
enddef
