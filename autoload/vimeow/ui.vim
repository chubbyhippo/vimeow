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
import autoload 'vimeow/core/port.vim' as P
import autoload 'vimeow/core/rc.vim' as Rc
import autoload 'vimeow/core/whichkey.vim' as WhichKey

const PROP_SELECTION = 'VimeowSelection'
const PROP_GRAB = 'VimeowGrab'
const PROP_MATCH = 'VimeowMatch'
const PROP_LABEL = 'VimeowAvyLabel'
const PROP_HINT = 'VimeowExpandHint'

const SCROLL_KEYS = {center: 'zz', top: 'zt', bottom: 'zb'}

const WHICH_KEY_ROWS = 12

var propsReady = false

def EnsureHighlights()
  if hlexists('VimeowSelection') == 0
    highlight default link VimeowSelection Visual
  endif
  if hlexists('VimeowMatch') == 0
    highlight default link VimeowMatch Search
  endif
  if hlexists('VimeowGrab') == 0
    highlight default link VimeowGrab DiffAdd
  endif
  if hlexists('VimeowAvyLead') == 0
    highlight default link VimeowAvyLead IncSearch
  endif
  if hlexists('VimeowHint') == 0
    highlight default link VimeowHint WarningMsg
  endif
enddef

def EnsurePropTypes()
  if propsReady
    return
  endif
  propsReady = true
  EnsureHighlights()
  for [name, hl, priority] in [
      [PROP_SELECTION, 'VimeowSelection', 10],
      [PROP_GRAB, 'VimeowGrab', 5],
      [PROP_MATCH, 'VimeowMatch', 20],
      [PROP_LABEL, 'VimeowAvyLead', 30],
      [PROP_HINT, 'VimeowHint', 25]]
    if empty(prop_type_get(name))
      prop_type_add(name, {highlight: hl, priority: priority, combine: true})
    endif
  endfor
enddef

def OffsetToPos(buf: number, offset: number): list<number>
  var acc = 0
  var lnum = 1
  for line in getbufline(buf, 1, '$')
    var width = len(line)
    if offset <= acc + width
      return [lnum, offset - acc + 1]
    endif
    acc += width + 1
    lnum += 1
  endfor
  var last = max([line('$', bufwinid(buf)), 1])
  return [last, 1]
enddef

export class VimUi implements P.UiPort
  var buf: number
  var whichKeyPopup: number = 0
  var whichKeyTimer: number = 0
  var avyPopups: list<number> = []
  var grabRange: P.OffsetRange = null_object
  var pendingKind: string = ''
  var pendingBuffer: string = ''

  def new(this.buf)
    EnsurePropTypes()
  enddef

  def Hint(text: string)
    echohl WarningMsg
    echomsg 'vimeow: ' .. text
    echohl None
  enddef

  def RevealCaret(at: string)
    var win = bufwinid(this.buf)
    if win == -1
      return
    endif
    win_execute(win, 'normal! ' .. get(SCROLL_KEYS, at, 'zz'))
  enddef

  def Info(title: string, body: string)
    var lines = [title, repeat('-', len(title))] + split(body, "\n", true)
    var width = 0
    for line in lines
      width = max([width, strdisplaywidth(line)])
    endfor
    popup_dialog(lines, {
      title: ' vimeow ',
      minwidth: min([width, &columns - 8]),
      maxwidth: &columns - 8,
      maxheight: &lines - 6,
      scrollbar: true,
      filter: 'popup_filter_yesno',
      filtermode: 'n',
      mapping: false,
    })
  enddef

  def Input(prompt: string, initial: string): string
    var answer = ''
    try
      answer = input(prompt .. ' ', initial)
    catch
      return ''
    endtry
    return answer
  enddef

  def RunCommand(id: string)
    execute id
  enddef

  def ScheduleWhichKey(kind: string, buffer: string)
    if !Rc.WhichKeyEnabled()
      return
    endif
    this.pendingKind = kind
    this.pendingBuffer = buffer
    if this.whichKeyTimer != 0
      timer_stop(this.whichKeyTimer)
    endif
    this.whichKeyTimer = timer_start(Rc.WhichKeyDelayMs(), (_) => this.ShowWhichKey())
  enddef

  def ShowWhichKey()
    this.whichKeyTimer = 0
    if this.pendingKind == ''
      return
    endif
    var rows = this.pendingKind == 'things'
        ? WhichKey.THINGS
        : WhichKey.KeypadRows(this.pendingBuffer)
    if empty(rows)
      return
    endif
    var keyWidth = 0
    for row in rows
      keyWidth = max([keyWidth, strdisplaywidth(row[0])])
    endfor
    var lines: list<string> = []
    for row in rows[0 : WHICH_KEY_ROWS - 1]
      lines = add(lines, printf(' %-*s  %s', keyWidth, row[0], row[1]))
    endfor
    if len(rows) > WHICH_KEY_ROWS
      lines = add(lines, printf(' … %d more', len(rows) - WHICH_KEY_ROWS))
    endif
    var title = this.pendingKind == 'things'
        ? ' thing: '
        : (this.pendingBuffer == '' ? ' SPC ' : ' SPC ' .. join(split(this.pendingBuffer, '\zs'), ' ') .. ' ')
    this.CloseWhichKey()
    this.whichKeyPopup = popup_create(lines, {
      title: title,
      line: &lines - len(lines) - 1,
      col: 1,
      minwidth: &columns - 2,
      highlight: 'Pmenu',
      border: [1, 0, 0, 0],
      borderchars: ['─'],
      zindex: 100,
      mapping: false,
    })
  enddef

  def CloseWhichKey()
    if this.whichKeyPopup != 0
      popup_close(this.whichKeyPopup)
      this.whichKeyPopup = 0
    endif
  enddef

  def HideWhichKey()
    this.pendingKind = ''
    if this.whichKeyTimer != 0
      timer_stop(this.whichKeyTimer)
      this.whichKeyTimer = 0
    endif
    this.CloseWhichKey()
  enddef

  def ClearProp(name: string)
    if bufexists(this.buf)
      prop_remove({type: name, bufnr: this.buf, all: true})
    endif
  enddef

  def AddRange(name: string, start: number, stop: number)
    if stop <= start || !bufexists(this.buf)
      return
    endif
    var from = OffsetToPos(this.buf, start)
    var to = OffsetToPos(this.buf, stop)
    prop_add(from[0], from[1], {
      type: name,
      bufnr: this.buf,
      end_lnum: to[0],
      end_col: to[1],
    })
  enddef

  def ShowExpandHints(positions: list<number>)
    this.ClearProp(PROP_HINT)
    var i = 0
    for position in positions
      var pos = OffsetToPos(this.buf, position)
      prop_add(pos[0], 0, {
        type: PROP_HINT,
        bufnr: this.buf,
        text: string((i + 1) % 10),
        text_align: 'after',
      })
      i += 1
    endfor
  enddef

  def ClearExpandHints()
    this.ClearProp(PROP_HINT)
  enddef

  def ShowAvyMatches(matches: list<P.OffsetRange>)
    this.ClearProp(PROP_MATCH)
    for match in matches
      this.AddRange(PROP_MATCH, match.start, match.end)
    endfor
  enddef

  def ShowAvyLabels(labels: list<P.AvyLabel>)
    this.ClearProp(PROP_LABEL)
    for label in labels
      var pos = OffsetToPos(this.buf, label.offset)
      prop_add(pos[0], pos[1], {
        type: PROP_LABEL,
        bufnr: this.buf,
        text: label.label,
        text_align: 'before',
      })
    endfor
  enddef

  def ClearAvy()
    this.ClearProp(PROP_MATCH)
    this.ClearProp(PROP_LABEL)
  enddef

  def ClearAll()
    for name in [PROP_SELECTION, PROP_GRAB, PROP_MATCH, PROP_LABEL, PROP_HINT]
      this.ClearProp(name)
    endfor
  enddef

  def SetGrabHighlight(range: P.OffsetRange)
    this.grabRange = range
    this.ClearProp(PROP_GRAB)
    if range != null_object
      this.AddRange(PROP_GRAB, range.start, range.end)
    endif
  enddef

  def PaintSelections(sels: list<P.SelRange>)
    this.ClearProp(PROP_SELECTION)
    for sel in sels
      this.AddRange(PROP_SELECTION, sel.SelStart(), sel.SelEnd())
    endfor
    if this.grabRange != null_object
      this.ClearProp(PROP_GRAB)
      this.AddRange(PROP_GRAB, this.grabRange.start, this.grabRange.end)
    endif
  enddef

  def ModeChanged(state: St.MeowState)
    b:vimeow_mode = state.mode
    if state.mode == St.INSERT && bufnr('%') == this.buf && mode() !=# 'i'
      timer_start(0, (_) => execute('startinsert'))
    endif
    redrawstatus
  enddef

  def Refresh(state: St.MeowState)
    b:vimeow_mode = state.mode
    redrawstatus
  enddef

  def StartTimer(ms: number, Cb: func): number
    return timer_start(ms, (_) => Cb())
  enddef

  def CancelTimer(id: number)
    timer_stop(id)
  enddef
endclass
