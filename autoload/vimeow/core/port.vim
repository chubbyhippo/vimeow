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

import autoload 'vimeow/core/state.vim' as St

export const REVEAL_CENTER = 'center'
export const REVEAL_TOP = 'top'
export const REVEAL_BOTTOM = 'bottom'

export class SelRange
  var anchor: number
  var active: number

  def new(this.anchor, this.active)
  enddef

  def Lo(): number
    return this.anchor < this.active ? this.anchor : this.active
  enddef

  def Hi(): number
    return this.anchor > this.active ? this.anchor : this.active
  enddef

  def HasSelection(): bool
    return this.anchor != this.active
  enddef
endclass

export class TextEdit
  var start: number
  var end: number
  var text: string

  def new(this.start, this.end, this.text)
  enddef
endclass

export class OffsetRange
  var start: number
  var end: number

  def new(this.start, this.end)
  enddef
endclass

export class LineRange
  var first: number
  var last: number

  def new(this.first, this.last)
  enddef
endclass

export class AvyLabel
  var offset: number
  var label: string

  def new(this.offset, this.label)
  enddef
endclass

export interface EditorPort
  def GetText(): string
  def GetSelections(): list<SelRange>
  def SetSelections(sels: list<SelRange>)
  def Edit(edits: list<TextEdit>)
  def IsWritable(): bool
  def VisibleLineRange(): LineRange
  def Undo()
  def CloseEditor()
  def SymbolRangeAt(offset: number): OffsetRange
endinterface

export interface ClipboardPort
  def Read(): string
  def Write(text: string)
endinterface

export interface UiPort
  def Hint(text: string)
  def RevealCaret(at: string)
  def Info(title: string, body: string)
  def Input(prompt: string, initial: string): string
  def RunCommand(id: string)
  def ScheduleWhichKey(kind: string, buffer: string)
  def HideWhichKey()
  def ShowExpandHints(positions: list<number>)
  def ClearExpandHints()
  def ShowAvyMatches(matches: list<OffsetRange>)
  def ShowAvyLabels(labels: list<AvyLabel>)
  def ClearAvy()
  def SetGrabHighlight(range: OffsetRange)
  def ModeChanged(state: St.MeowState)
  def Refresh(state: St.MeowState)
  def StartTimer(ms: number, Cb: func): number
  def CancelTimer(id: number)
endinterface

export class Ctx
  var port: EditorPort
  var clipboard: ClipboardPort
  var ui: UiPort
  var state: St.MeowState

  def new(this.port, this.clipboard, this.ui, this.state)
  enddef

  def SetMode(mode: string)
    this.state.mode = mode
    if mode != St.KEYPAD
      this.state.keypad = ''
    endif
    this.ui.ModeChanged(this.state)
  enddef
endclass
