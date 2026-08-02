vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

var out: list<string> = []
var failures = 0

def Check(name: string, cond: bool)
  if cond
    add(out, '  ok   ' .. name)
  else
    add(out, '  FAIL ' .. name)
    failures += 1
  endif
  writefile(out, expand('$VIMEOW_TEST_OUT'))
enddef

source plugin/vimeow.vim

import autoload 'vimeow/adapter.vim' as Adapter
import autoload 'vimeow.vim' as Vimeow
import autoload 'vimeow/core/rc.vim' as Rc
import autoload 'vimeow/core/state.vim' as St

def FreshBuf(lines: list<string>): number
  enew!
  var target = bufnr('%')
  setline(1, lines)
  Adapter.Attach(target)
  cursor(1, 1)
  return target
enddef

def Keys(target: number, keys: string)
  for i in range(len(keys))
    Adapter.HandleKey(target, keys[i])
  endfor
enddef

var buf = FreshBuf(['hello world'])
var entry = Adapter.ContextFor(buf)
Check('attach produced a context', !empty(entry))
Check('the buffer reports NORMAL', get(b:, 'vimeow_mode', '') == St.NORMAL)
Check('the statusline reports the mode', Vimeow.Statusline() == 'MEOW NORMAL')

Check('w is mapped to the vimeow handler', maparg('w', 'n') =~ 'HandleKey')
Check('SPC is mapped to the vimeow handler', maparg('<Space>', 'n') =~ 'HandleKey')
Check('ESC is mapped to the escape handler', maparg('<Esc>', 'n') =~ 'HandleEscape')
Check('Alt+; enters the keypad from INSERT', maparg('<M-;>', 'i') =~ 'EnterKeypadFromInsert')
Check('the C-e chord is mapped', maparg('<C-e>', 'n') =~ 'HandleChord')
Check('the M-f chord is mapped', maparg('<M-f>', 'n') =~ 'HandleChord')
var chordMaps = 0
for spelling in Rc.ChordOrder()
  if maparg(Adapter.VimChordKey(spelling), 'n') =~ 'HandleChord'
    chordMaps += 1
  endif
endfor
Check('every rc chord has a buffer keymap (' .. chordMaps .. '/32)', chordMaps == 32)

Keys(buf, 'w')
entry = Adapter.ContextFor(buf)
Check('w selects [0,5)', entry.sels[0].SelStart() == 0 && entry.sels[0].SelEnd() == 5)
Check('the selection painted a text property',
      len(prop_list(1, {bufnr: buf, types: ['VimeowSelection']})) > 0)
Check('the caret followed the selection', col('.') == 6)

buf = FreshBuf(['hello'])
Keys(buf, 'l')
Check('l moved the caret to offset 1', Adapter.ContextFor(buf).sels[0].active == 1)

buf = FreshBuf(['one two', 'three'])
Keys(buf, 'x')
entry = Adapter.ContextFor(buf)
Check('x selects the line [0,7)', entry.sels[0].SelStart() == 0 && entry.sels[0].SelEnd() == 7)

buf = FreshBuf(['hello world'])
Keys(buf, 'ws')
Check('w then s killed the word', getline(1) == ' world')
Check('the kill wrote the clipboard', getreg('"') == 'hello')

buf = FreshBuf(['hello world'])
Keys(buf, 'wy')
Check('w then y copied the word', getreg('"') == 'hello')

buf = FreshBuf(['hello world'])
Keys(buf, 'wd')
Check('w then d deleted the selection', getline(1) == ' world')

buf = FreshBuf(['one two', 'three'])
Keys(buf, 'xs')
Check('a line kill takes the newline too', getline(1) == 'three')

buf = FreshBuf(['a', 'b', 'c'])
Keys(buf, '.bs')
Check('killing the buffer thing empties it', getline(1, '$') == [''])

buf = FreshBuf(['alpha beta'])
Keys(buf, ' ')
Check('SPC enters KEYPAD', Adapter.ContextFor(buf).state.mode == St.KEYPAD)
Keys(buf, 'mf')
entry = Adapter.ContextFor(buf)
Check('SPC m f ran forward-word and left KEYPAD',
      entry.state.mode == St.NORMAL && entry.sels[0].active == 5)

buf = FreshBuf(['hello world'])
Adapter.HandleChord(buf, 'C-e', '<C-e>')
Check('the C-e chord ran move-end-of-line', Adapter.ContextFor(buf).sels[0].active == 11)

buf = FreshBuf(['hello world'])
Adapter.HandleChord(buf, 'M-f', '<M-f>')
Check('the M-f chord ran forward-word', Adapter.ContextFor(buf).sels[0].active == 5)

buf = FreshBuf(['hello world'])
Adapter.HandleChord(buf, 'M-u', '<M-u>')
Check('the M-u chord upcased the word', getline(1) == 'HELLO world')

buf = FreshBuf(['aa bb aa bb'])
Keys(buf, '.bG')
Check('the grab painted its highlight',
      len(prop_list(1, {bufnr: buf, types: ['VimeowGrab']})) > 0)

buf = FreshBuf(range(1, 200)->mapnew((_, n) => 'line ' .. n))
cursor(100, 1)
Adapter.HandleChord(buf, 'C-l', '<C-l>')
Check('C-l recentred the window', line('w0') < 100 && line('w$') > 100)

enew!
split
var top = win_getid()
wincmd j
var bottom = win_getid()
Check('two windows exist', top != bottom)
win_gotoid(bottom)
Vimeow.WindmoveStep('up')
Check('windmove up reached the other window', win_getid() == top)
Vimeow.AceWindow()
Check('ace-window with two windows jumps to the other', win_getid() == bottom)
only

var scratch = bufadd('vimeow-scratch-nofile')
bufload(scratch)
setbufvar(scratch, '&buftype', 'nofile')
Check('a scratch nofile surface is not a meow editor',
      empty(Adapter.Attach(scratch)))
Check('the nofile surface is named for the attach policy',
      Adapter.SurfaceOf(scratch) == 'nofile')

var helpbuf = bufadd('vimeow-scratch-help')
bufload(helpbuf)
setbufvar(helpbuf, '&buftype', 'help')
Check('a help surface still gets meow, read-only',
      !empty(Adapter.Attach(helpbuf)) && !getbufvar(helpbuf, '&modifiable'))

writefile(out + [printf('smoke: %d checks, %d failed', len(out), failures)],
          expand('$VIMEOW_TEST_OUT'))
execute 'cquit ' .. (failures == 0 ? 0 : 1)
