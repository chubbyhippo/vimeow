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
import autoload 'vimeow/core/text.vim' as T
import autoload 'vimeow/core/motions.vim' as Motions

export const RECENTER_COMMAND = 'recenter-top-bottom'
export const SCROLL_UP_COMMAND = 'scroll-up-command'
export const SCROLL_DOWN_COMMAND = 'scroll-down-command'

const SCREEN_CONTEXT_LINES = 2

export const RECENTER_POSITIONS = [P.REVEAL_CENTER, P.REVEAL_TOP, P.REVEAL_BOTTOM]

export def RecenterPosition(phase: number): string
  var total = len(RECENTER_POSITIONS)
  return RECENTER_POSITIONS[((phase % total) + total) % total]
enddef

export def NextRecenterPhase(previousCommand: string, phase: number): number
  return previousCommand == RECENTER_COMMAND ? phase + 1 : 0
enddef

export def PageLineCount(ctx: P.Ctx): number
  var vis = ctx.port.VisibleLineRange()
  var count: number
  if vis == null_object
    count = T.LineCount(ctx.port.GetText())
  else
    count = vis.last - vis.first + 1
  endif
  return max([1, count - SCREEN_CONTEXT_LINES])
enddef

def Recenter(ctx: P.Ctx)
  ctx.state.recenterPhase = NextRecenterPhase(ctx.state.lastCommand, ctx.state.recenterPhase)
  ctx.state.lastCommand = RECENTER_COMMAND
  ctx.ui.RevealCaret(RecenterPosition(ctx.state.recenterPhase))
enddef

def ScrollUp(ctx: P.Ctx)
  Motions.LineOrExpand(ctx, PageLineCount(ctx) * ctx.state.TakeCount(1))
  ctx.state.lastCommand = SCROLL_UP_COMMAND
enddef

def ScrollDown(ctx: P.Ctx)
  Motions.LineOrExpand(ctx, -PageLineCount(ctx) * ctx.state.TakeCount(1))
  ctx.state.lastCommand = SCROLL_DOWN_COMMAND
enddef

export def Commands(): dict<func>
  var cmds: dict<func> = {}
  cmds[RECENTER_COMMAND] = Recenter
  cmds[SCROLL_UP_COMMAND] = ScrollUp
  cmds[SCROLL_DOWN_COMMAND] = ScrollDown
  return cmds
enddef
