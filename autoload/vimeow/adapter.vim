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

import autoload 'vimeow/core.vim' as Core
import autoload 'vimeow/core/state.vim' as St
import autoload 'vimeow/core/port.vim' as P
import autoload 'vimeow/core/rc.vim' as Rc
import autoload 'vimeow/core/engine.vim' as Engine
import autoload 'vimeow/core/chord.vim' as Chord
import autoload 'vimeow/core/chords.vim' as Chords
import autoload 'vimeow/core/attachpolicy.vim' as AttachPolicy
import autoload 'vimeow/ui.vim' as Ui

const VIM_KEY_NAMES = {
  ' ': 'Space',
  "\t": 'Tab',
  '\': 'Bslash',
  '|': 'Bar',
  '<': 'lt',
}

var contexts: dict<any> = {}

export class VimEditor implements P.EditorPort
  var buf: number

  def new(this.buf)
  enddef

  def GetText(): string
    return join(getbufline(this.buf, 1, '$'), "\n")
  enddef

  def GetSelections(): list<P.SelRange>
    var ctx = get(contexts, string(this.buf), {})
    if empty(ctx)
      return [P.SelRange.new(0, 0)]
    endif
    var out: list<P.SelRange> = []
    for sel in ctx.sels
      add(out, P.SelRange.new(sel.anchor, sel.active))
    endfor
    return out
  enddef

  def SetSelections(sels: list<P.SelRange>)
    var entry = get(contexts, string(this.buf), {})
    if empty(entry)
      return
    endif
    var out: list<P.SelRange> = []
    for sel in sels
      add(out, P.SelRange.new(sel.anchor, sel.active))
    endfor
    entry.sels = out
    var win = bufwinid(this.buf)
    if win != -1 && !empty(out)
      var pos = OffsetToRowCol(this.buf, out[0].active)
      win_execute(win, printf('call cursor(%d, %d)', pos[0], pos[1]))
    endif
    entry.ui.PaintSelections(out)
  enddef

  def Edit(edits: list<P.TextEdit>)
    var entry = get(contexts, string(this.buf), {})
    if !empty(entry)
      entry.ui.ClearAll()
    endif
    var text = this.GetText()
    var sorted = copy(edits)
    sort(sorted, (a, b) => b.start - a.start)
    for edit in sorted
      text = strpart(text, 0, edit.start) .. edit.text .. strpart(text, edit.end)
    endfor
    var lines = split(text, "\n", true)
    setbufline(this.buf, 1, lines)
    var extra = len(getbufline(this.buf, 1, '$')) - len(lines)
    if extra > 0
      deletebufline(this.buf, len(lines) + 1, '$')
    endif
  enddef

  def IsWritable(): bool
    return getbufvar(this.buf, '&modifiable') && !getbufvar(this.buf, '&readonly')
  enddef

  def VisibleLineRange(): P.LineRange
    var win = bufwinid(this.buf)
    if win == -1
      return null_object
    endif
    return P.LineRange.new(line('w0', win) - 1, line('w$', win) - 1)
  enddef

  def Undo()
    var win = bufwinid(this.buf)
    if win != -1
      win_execute(win, 'silent! undo')
    endif
  enddef

  def CloseEditor()
    var win = bufwinid(this.buf)
    if win != -1
      win_execute(win, 'silent! close')
    endif
  enddef

  def SymbolRangeAt(offset: number): P.OffsetRange
    return null_object
  enddef
endclass

const HAS_SYSTEM_CLIPBOARD = has('clipboard')

export class VimClipboard implements P.ClipboardPort
  var fallback: string = ''

  def Read(): string
    if HAS_SYSTEM_CLIPBOARD
      var reg = getreg('+')
      if reg != ''
        return reg
      endif
    endif
    var unnamed = getreg('"')
    return unnamed != '' ? unnamed : this.fallback
  enddef

  def Write(text: string)
    this.fallback = text
    setreg('"', text)
    if HAS_SYSTEM_CLIPBOARD
      setreg('+', text)
    endif
  enddef
endclass

def OffsetToRowCol(buf: number, offset: number): list<number>
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
  return [max([len(getbufline(buf, 1, '$')), 1]), 1]
enddef

def RowColToOffset(buf: number, lnum: number, col: number): number
  var acc = 0
  var i = 1
  for line in getbufline(buf, 1, '$')
    if i == lnum
      return acc + col - 1
    endif
    acc += len(line) + 1
    i += 1
  endfor
  return acc
enddef

export def SurfaceOf(buf: number): string
  var buftype = getbufvar(buf, '&buftype')
  return buftype == '' ? 'file-editor' : buftype
enddef

def SyncCursorToState(buf: number)
  var entry = get(contexts, string(buf), {})
  if empty(entry)
    return
  endif
  var win = bufwinid(buf)
  if win == -1
    return
  endif
  var pos = getcurpos(win)
  var off = RowColToOffset(buf, pos[1], pos[2])
  var head = entry.sels[0]
  if head.anchor == head.active
    entry.sels[0] = P.SelRange.new(off, off)
  else
    entry.sels[0] = P.SelRange.new(head.anchor, off)
  endif
enddef

def BoundKeys(): dict<bool>
  var out: dict<bool> = {' ': true, '-': true}
  for char in keys(Rc.Defaults().normal)
    out[char] = true
  endfor
  for char in keys(Rc.Cfg().normal)
    out[char] = true
  endfor
  for char in keys(Rc.Defaults().motion)
    out[char] = true
  endfor
  for char in keys(Rc.Cfg().motion)
    out[char] = true
  endfor
  for digit in range(10)
    out[string(digit)] = true
  endfor
  return out
enddef

export def VimChordKey(spelling: string): string
  var rest = spelling
  var prefix = ''
  while len(rest) >= 2 && rest[1] == '-' && stridx('CMS', rest[0]) >= 0
    prefix ..= rest[0] .. '-'
    rest = strpart(rest, 2)
  endwhile
  if len(rest) != 1 || prefix == ''
    return ''
  endif
  return '<' .. prefix .. get(VIM_KEY_NAMES, rest, rest) .. '>'
enddef

def ChordKeymaps(): dict<string>
  var out: dict<string> = {}
  for spelling in Rc.ChordOrder()
    var lhs = VimChordKey(spelling)
    if lhs != ''
      out[lhs] = spelling
    endif
  endfor
  return out
enddef

export def HandleKey(buf: number, key: string)
  var entry = get(contexts, string(buf), {})
  if empty(entry)
    return
  endif
  SyncCursorToState(buf)
  Engine.HandleChar(entry.ctx, key)
enddef

export def HandleChord(buf: number, spelling: string, lhs: string)
  var entry = get(contexts, string(buf), {})
  if empty(entry)
    return
  endif
  SyncCursorToState(buf)
  if !Chords.Dispatch(entry.ctx, Chord.Parse(spelling))
    feedkeys(eval('"\' .. lhs .. '"'), 'n')
  endif
enddef

export def HandleEscape(buf: number)
  var entry = get(contexts, string(buf), {})
  if empty(entry)
    return
  endif
  Engine.EscapeKey(entry.ctx)
enddef

export def EnterKeypadFromInsert(buf: number)
  var entry = get(contexts, string(buf), {})
  if empty(entry)
    return
  endif
  Engine.EnterKeypad(entry.ctx)
  stopinsert
enddef

def SetKeymaps(buf: number)
  for key in keys(BoundKeys())
    var lhs = key == ' ' ? '<Space>' : (key == '<' ? '<lt>' : key)
    execute printf(
      'nnoremap <buffer> <nowait> <silent> %s <ScriptCmd>HandleKey(%d, %s)<CR>',
      lhs, buf, string(key))
  endfor
  for [lhs, spelling] in items(ChordKeymaps())
    execute printf(
      'nnoremap <buffer> <nowait> <silent> %s <ScriptCmd>HandleChord(%d, %s, %s)<CR>',
      lhs, buf, string(spelling), string(lhs))
    if spelling != Chords.KEYPAD_ENTRY_CHORD
      execute printf(
        'inoremap <buffer> <nowait> <silent> %s <ScriptCmd>HandleChord(%d, %s, %s)<CR>',
        lhs, buf, string(spelling), string(lhs))
    endif
  endfor
  execute printf(
    'nnoremap <buffer> <nowait> <silent> <Esc> <ScriptCmd>HandleEscape(%d)<CR>', buf)
  execute printf(
    'inoremap <buffer> <nowait> <silent> <M-;> <ScriptCmd>EnterKeypadFromInsert(%d)<CR>', buf)
enddef

def ClearKeymaps(buf: number)
  for key in keys(BoundKeys())
    var lhs = key == ' ' ? '<Space>' : (key == '<' ? '<lt>' : key)
    silent! execute 'nunmap <buffer> ' .. lhs
  endfor
  for [lhs, spelling] in items(ChordKeymaps())
    silent! execute 'nunmap <buffer> ' .. lhs
    if spelling != Chords.KEYPAD_ENTRY_CHORD
      silent! execute 'iunmap <buffer> ' .. lhs
    endif
  endfor
enddef

export def Attach(buf: number): dict<any>
  if has_key(contexts, string(buf))
    return contexts[string(buf)]
  endif
  Core.Init()
  var surface = SurfaceOf(buf)
  if AttachPolicy.AttachMode(surface) == ''
    return {}
  endif

  var state = St.NewState()
  var port = VimEditor.new(buf)
  var ui = Ui.VimUi.new(buf)
  var ctx = P.Ctx.new(port, VimClipboard.new(), ui, state)
  contexts[string(buf)] = {
    ctx: ctx, ui: ui, state: state, port: port,
    sels: [P.SelRange.new(0, 0)],
  }

  if !AttachPolicy.IsWritableSurface(surface)
    setbufvar(buf, '&modifiable', 0)
  endif
  var win = bufwinid(buf)
  if win != -1
    win_execute(win, 'setlocal virtualedit=onemore')
  endif
  setbufvar(buf, 'vimeow_mode', state.mode)
  SetKeymaps(buf)

  augroup vimeow_buf
    execute printf('autocmd! * <buffer=%d>', buf)
    execute printf('autocmd InsertLeave <buffer=%d> call vimeow#adapter#OnInsertLeave(%d)', buf, buf)
    execute printf('autocmd BufWipeout,BufDelete <buffer=%d> call vimeow#adapter#OnBufGone(%d)', buf, buf)
  augroup END

  ui.Refresh(state)
  return contexts[string(buf)]
enddef

export def OnInsertLeave(buf: number)
  var entry = get(contexts, string(buf), {})
  if empty(entry)
    return
  endif
  if entry.state.mode == St.INSERT
    entry.state.mode = St.NORMAL
    entry.ui.Refresh(entry.state)
  endif
enddef

export def OnBufGone(buf: number)
  if has_key(contexts, string(buf))
    remove(contexts, string(buf))
  endif
enddef

export def ContextFor(buf: number): dict<any>
  return get(contexts, string(buf), {})
enddef

export def ReloadUserRc(lines: list<string>)
  Rc.SetUserLines(lines)
  for key in keys(contexts)
    var buf = str2nr(key)
    if bufexists(buf)
      ClearKeymaps(buf)
      SetKeymaps(buf)
    endif
  endfor
enddef
