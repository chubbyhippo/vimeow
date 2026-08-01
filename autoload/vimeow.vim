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

import autoload 'vimeow/adapter.vim' as Adapter
import autoload 'vimeow/defaultrc.vim' as DefaultRc
import autoload 'vimeow/core.vim' as Core
import autoload 'vimeow/core/rc.vim' as Rc
import autoload 'vimeow/core/state.vim' as St
import autoload 'vimeow/core/windmove.vim' as Windmove
import autoload 'vimeow/core/acewindow.vim' as Ace
import autoload 'vimeow/core/resize.vim' as Resize
import autoload 'vimeow/core/attachpolicy.vim' as AttachPolicy
import autoload 'vimeow/core/toolwindowescape.vim' as ToolWindowEscape

const ESC = "\<Esc>"
const ACE_LABEL_ZINDEX = 300
const SETTINGS_SEED =<< trim END
  " ~/.vimeowrc — your personal meow layer for Vim.
  "
  " Each line is one rc line and overrides the bundled default entry by entry.
  " The full default layout is already active; only what you list here changes.
  " Reload with SPC c M. See the bundled .vimeowrc inside the plugin for the
  " complete default and the full syntax guide.
  "
  "   nmap S avy-goto-char-timer
  "   map <leader>ff <action>(browse edit)
  "   desc <leader>f find
  "   cmap C-f ignore
  "   set nowhich-key
END

var lastEditorWindow: number = 0

export def SettingsPath(): string
  return expand('~/' .. Rc.FILE_NAME)
enddef

def UserLines(): list<string>
  var path = SettingsPath()
  if !filereadable(path)
    return []
  endif
  return readfile(path)
enddef

export def Setup()
  Core.Init()
  Rc.InitDefaults(DefaultRc.LINES)
  Rc.SetUserLines(UserLines())
enddef

export def EditRc()
  var path = SettingsPath()
  if !filereadable(path)
    writefile(SETTINGS_SEED, path)
  endif
  execute 'edit ' .. fnameescape(path)
enddef

export def ReloadRc()
  Adapter.ReloadUserRc(UserLines())
  echomsg 'vimeow: reloaded ' .. Rc.FILE_NAME
enddef

export def Statusline(): string
  var mode = get(b:, 'vimeow_mode', '')
  return mode == '' ? '' : 'MEOW ' .. mode
enddef

export def WindmoveStep(dir: string)
  var before = win_getid()
  execute Windmove.Plan(dir)
  if win_getid() == before
    echohl WarningMsg | echomsg Windmove.NoWindowMessage(dir) | echohl None
  endif
enddef

export def WindmoveSwap(dir: string)
  var w1 = win_getid()
  var b1 = winbufnr(w1)
  execute Windmove.Plan(dir)
  var w2 = win_getid()
  if w2 == w1
    echohl WarningMsg | echomsg Windmove.NoWindowMessage(dir) | echohl None
    return
  endif
  var b2 = winbufnr(w2)
  win_execute(w1, 'buffer ' .. b2)
  win_execute(w2, 'buffer ' .. b1)
enddef

def AceCandidates(): list<dict<any>>
  var out: list<dict<any>> = []
  for win in gettabinfo(tabpagenr())[0].windows
    var pos = win_screenpos(win)
    add(out, {item: win, x: pos[1], y: pos[0]})
  endfor
  return out
enddef

def PaintAceLabels(wins: list<any>, labelList: list<string>): list<number>
  var popups: list<number> = []
  var i = 0
  for win in wins
    if i < len(labelList)
      var pos = win_screenpos(win)
      add(popups, popup_create(' ' .. labelList[i] .. ' ', {
        line: pos[0],
        col: pos[1],
        highlight: 'VimeowAvyLead',
        zindex: ACE_LABEL_ZINDEX,
        mapping: false,
      }))
    endif
    i += 1
  endfor
  return popups
enddef

def ClearAceLabels(popups: list<number>)
  for p in popups
    popup_close(p)
  endfor
enddef

def ReadAcePick(wins: list<any>, labelList: list<string>): number
  var popups = PaintAceLabels(wins, labelList)
  redraw
  var input = ''
  var picked = 0
  while true
    var ch = getcharstr()
    if ch == '' || ch == ESC
      break
    endif
    input ..= ch
    var remaining = Ace.Matches(labelList, input)
    if empty(remaining)
      break
    endif
    if len(remaining) == 1 && remaining[0] == input
      var idx = index(labelList, input)
      if idx >= 0 && idx < len(wins)
        picked = wins[idx]
      endif
      break
    endif
  endwhile
  ClearAceLabels(popups)
  return picked
enddef

def OtherWindow(wins: list<any>): number
  var current = win_getid()
  for win in wins
    if win != current
      return win
    endif
  endfor
  return 0
enddef

def AceTarget(): number
  var wins = Ace.Ordered(AceCandidates())
  var plan = Ace.Plan(len(wins))
  if plan == Ace.PLAN_NONE
    echohl WarningMsg | echomsg Windmove.NoWindowMessage('other') | echohl None
    return 0
  endif
  if plan == Ace.PLAN_OTHER
    return OtherWindow(wins)
  endif
  return ReadAcePick(wins, Ace.Labels(len(wins)))
enddef

export def AceWindow()
  var target = AceTarget()
  if target != 0
    win_gotoid(target)
  endif
enddef

export def AceSwapWindow()
  var from = win_getid()
  var target = AceTarget()
  if target == 0 || target == from
    return
  endif
  var here = winbufnr(from)
  var there = winbufnr(target)
  win_execute(from, 'buffer ' .. there)
  win_execute(target, 'buffer ' .. here)
  win_gotoid(target)
enddef

export def AceResize()
  var keys = Resize.Keys()
  if empty(keys)
    echohl WarningMsg | echomsg 'vimeow: no resize keys in the rc' | echohl None
    return
  endif
  var entry = Adapter.ContextFor(bufnr('%'))
  if empty(entry)
    return
  endif
  var prompt = 'resize: ' .. join(keys, ' ') .. ' — ESC when done'
  while true
    echo 'vimeow: ' .. prompt
    var ch = getcharstr()
    if ch == '' || ch == ESC
      break
    endif
    if !Resize.Dispatch(entry.ctx, ch)
      break
    endif
    redraw
  endwhile
  echo ''
enddef

def IsToolWindow(buf: number): bool
  return AttachPolicy.AttachMode(Adapter.SurfaceOf(buf)) == ''
enddef

export def EscapeFromToolWindow()
  var win = win_getid()
  var surface = Adapter.SurfaceOf(bufnr('%')) .. '@' .. win
  if !ToolWindowEscape.OnEscape(surface, float2nr(reltimefloat(reltime()) * 1000))
    return
  endif
  if lastEditorWindow != 0 && win_id2win(lastEditorWindow) != 0
    win_gotoid(lastEditorWindow)
  endif
enddef

export def OnWinEnter()
  var buf = bufnr('%')
  if IsToolWindow(buf)
    return
  endif
  ToolWindowEscape.Reset()
  lastEditorWindow = win_getid()
enddef

export def OnBufWinEnter()
  var buf = str2nr(expand('<abuf>'))
  if buf == 0
    buf = bufnr('%')
  endif
  var win = bufwinid(buf)
  if win == -1 || win_gettype(win) == 'autocmd'
    return
  endif
  if !IsToolWindow(buf)
    Adapter.Attach(buf)
    return
  endif
  execute printf(
    'nnoremap <buffer=%d> <nowait> <silent> <Esc> <ScriptCmd>EscapeFromToolWindow()<CR>', buf)
enddef
