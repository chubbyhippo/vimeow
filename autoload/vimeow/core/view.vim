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

export const RECENTER_COMMAND = 'recenter-top-bottom'

export const RECENTER_POSITIONS = [P.REVEAL_CENTER, P.REVEAL_TOP, P.REVEAL_BOTTOM]

export def RecenterPosition(phase: number): string
  var n = len(RECENTER_POSITIONS)
  return RECENTER_POSITIONS[((phase % n) + n) % n]
enddef

export def NextRecenterPhase(previousCommand: string, phase: number): number
  return previousCommand == RECENTER_COMMAND ? phase + 1 : 0
enddef

def Recenter(ctx: P.Ctx)
  ctx.st.recenterPhase = NextRecenterPhase(ctx.st.lastCommand, ctx.st.recenterPhase)
  ctx.st.lastCommand = RECENTER_COMMAND
  ctx.ui.RevealCaret(RecenterPosition(ctx.st.recenterPhase))
enddef

export def Commands(): dict<func>
  var cmds: dict<func> = {}
  cmds[RECENTER_COMMAND] = Recenter
  return cmds
enddef
