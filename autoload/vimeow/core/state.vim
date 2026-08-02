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

export const NORMAL = 'NORMAL'
export const INSERT = 'INSERT'
export const MOTION = 'MOTION'
export const KEYPAD = 'KEYPAD'

export const SEL_NONE = 'NONE'
export const SEL_CHAR = 'CHAR'
export const SEL_WORD = 'WORD'
export const SEL_SYMBOL = 'SYMBOL'
export const SEL_LINE = 'LINE'
export const SEL_BLOCK = 'BLOCK'
export const SEL_FIND = 'FIND'
export const SEL_TILL = 'TILL'
export const SEL_VISIT = 'VISIT'
export const SEL_JOIN = 'JOIN'
export const SEL_TRANSIENT = 'TRANSIENT'

export const PENDING_FIND = 'FIND'
export const PENDING_TILL = 'TILL'
export const PENDING_INNER = 'INNER'
export const PENDING_BOUNDS = 'BOUNDS'
export const PENDING_BEGIN = 'BEGIN'
export const PENDING_END = 'END'

export class SavedSelection
  var selType: string
  var anchor: number
  var active: number
  def new(this.selType, this.anchor, this.active)
  enddef
endclass

export class MeowState
  public var mode: string = NORMAL
  public var selType: string = SEL_NONE
  public var selExpand: bool = false
  public var pending: string = ''

  public var pendingCount: number = 0
  public var negative: bool = false

  public var lastFind: dict<any> = {}

  public var searchHistory: list<string> = []

  public var selectionHistory: list<SavedSelection> = []

  public var lastSelection: SavedSelection = null_object

  public var goalColumn: number = -1

  public var lastCommand: string = ''
  public var recenterPhase: number = 0

  public var grab: dict<number> = {}

  public var avy: dict<any> = {}

  public var aceWindow: dict<any> = {}

  public var keypad: string = ''

  public var keypadPreviousState: string = NORMAL

  public var unit: list<string> = []
  public var lastKeys: list<string> = []
  public var replaying: bool = false

  public var replayDepth: number = 0
  public var noremapDepth: number = 0

  def TakeCount(fallback: number = 1): number
    var count = this.pendingCount == 0 ? fallback : this.pendingCount
    var signed = this.negative ? -count : count
    this.pendingCount = 0
    this.negative = false
    return signed
  enddef

  def HasGrab(): bool
    return !empty(this.grab)
  enddef

  def HasAvy(): bool
    return !empty(this.avy)
  enddef
endclass

export def NewState(): MeowState
  return MeowState.new()
enddef
