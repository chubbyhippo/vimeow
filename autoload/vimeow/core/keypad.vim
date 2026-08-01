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
import autoload 'vimeow/core/rc.vim' as Rc
import autoload 'vimeow/core/engine.vim' as Engine

export const CHEATSHEET = join([
  'The bundled default layout (meow''s suggested QWERTY) — every key below can',
  'be rebound from the ~/.vimeowrc settings file (SPC c m opens it).',
  '',
  'NORMAL — selection first, then act',
  '  h j k l  move (cancel selection)       H J K L  extend char selection',
  '  w / W    mark word / symbol            e / E    next word / symbol end',
  '  b / B    back word / symbol            x        line (repeat: extend)',
  '  f / t    find / till char (inclusive / exclusive)',
  '  o / O    block / to end of block       m        select join region',
  '  , / .    inner / bounds of thing       [ / ]    to beginning / end of thing',
  '     things: r round  s square  c curly  g string  e symbol  w window',
  '             b buffer  p paragraph  l line  v visual line  d defun  . sentence',
  '  1-9, 0   expand selection by N units (0 = 10); without selection: count',
  '  -        negative argument              ;        reverse selection',
  '  i / a    insert at start / end          I / A    open line above / below',
  '  c        change                         s        kill (cut)',
  '  d / D    delete char/sel fwd / back     y        save (copy)',
  '  p        yank (paste at point)          r        replace selection with clipboard',
  '  u        undo                           ''        repeat last command',
  '  v        visit (regexp search+select)   n        search next (reversed sel = backward)',
  '  z        pop selection (or grab)        g        cancel selection / cursors',
  '  G        grab (secondary selection)     R / Y    swap grab / sync grab',
  '  Q / X    goto line                      q        close window',
  '  S        avy: type chars, home-row labels jump anywhere on screen',
  '  ESC      insert -> normal; drops extra cursors',
  '  BEACON   grab a region (G), then select w/x/f... inside it:',
  '           a cursor lands on every match — edit them all, ESC to finish',
  '',
  'EMACS CHORDS (from the rc — cmap lines, rebindable)',
  '  C-f/b/n/p  char/line move            C-a/e      beginning/end of line',
  '  M-f/b      word move                 M-a/e      backward/forward sentence',
  '  M-< / M->  buffer boundary           M-{ / M-}  paragraph move',
  '  M-u/l/c    up/down/capitalize word   M-d        kill word',
  '  C-l        recenter top/bottom       C-o        open line',
  '  C-/ C-_    undo                      C-k / C-w  kill line / region',
  '  M-w        save (copy)               C-y        yank',
  '  C-g        cancel selection          M-m        back to indentation',
  '  M-\        delete horizontal space   M-SPC      just one space',
  '             no selection: just moves; with one active: extends it',
  '',
  'KEYPAD (SPC — or Alt+; from ANY state, INSERT included; returns there)',
  '  SPC b buffers   SPC x file/buffer/window   SPC c commands   SPC m meta',
  '  SPC w windows   SPC 0-9 count   SPC ? this sheet   SPC / describe key',
  '  SPC c m open the ~/.vimeowrc settings file   SPC c M reload it',
  '  REPEAT  some entries start a run (Emacs repeat-mode): after',
  '          SPC . e keep tapping . / , to walk the location list, after',
  '          SPC w i keep tapping i (or = - o u 0) to keep resizing — any',
  '          other key ends the run and keeps its normal meaning',
  '',
  '~/.vimeowrc lines: nmap <key> <action>(excommand) | nmap <key> meow-command |',
  '  nmap <key> <meow keys> | mmap ... (MOTION) | map <leader><seq> ... |',
  '  desc <leader><seq> text | cmap <chord> <target> | resizemap <key> <target> |',
  '  set nowhich-key | repeat <group> <key> <target> — the defaults ship as a',
  '  bundled .vimeowrc inside the plugin; your file overrides them key by key',
], "\n")

def Spaced(seq: string): string
  var parts: list<string> = []
  for i in range(len(seq))
    add(parts, seq[i])
  endfor
  return join(parts, ' ')
enddef

def Describe(ctx: P.Ctx, c: string)
  var descsMap = Rc.KeypadDescs()[0]
  var pair = Rc.Keypad()
  var m = pair[0]
  var seqs: list<string> = []
  for seq in pair[1]
    if strpart(seq, 0, len(c)) == c
      add(seqs, seq)
    endif
  endfor
  sort(seqs)
  var lines: list<string> = []
  for seq in seqs
    var b = m[seq]
    var target = get(b, 'action', get(b, 'command', get(b, 'keys', '')))
    var desc = has_key(descsMap, seq) ? '  (' .. descsMap[seq] .. ')' : ''
    add(lines, 'SPC ' .. Spaced(seq) .. '  ->  ' .. target .. desc)
  endfor
  var body = join(lines, "\n")
  if body == ''
    body = 'SPC ' .. c .. ' is undefined'
  endif
  ctx.ui.Info('Meow Describe: SPC ' .. c, body)
enddef

export def Exit(ctx: P.Ctx)
  ctx.ui.HideWhichKey()
  ctx.SetMode(ctx.st.keypadPreviousState)
enddef

export def Key(ctx: P.Ctx, c: string)
  var st = ctx.st
  ctx.ui.HideWhichKey()
  var pair = Rc.Keypad()
  var m = pair[0]
  var order = pair[1]
  var buf = st.keypad

  if buf == '/'
    Describe(ctx, c)
    Exit(ctx)
    return
  endif
  if buf == ''
    if c >= '0' && c <= '9'
      st.pendingCount = st.pendingCount * 10 + (char2nr(c) - char2nr('0'))
      Exit(ctx)
      return
    endif
    if c == '?'
      Exit(ctx)
      ctx.ui.Info('Meow Cheatsheet', CHEATSHEET)
      return
    endif
    if c == '/'
      st.keypad = st.keypad .. '/'
      return
    endif
  endif

  st.keypad = st.keypad .. c
  var cur = st.keypad
  if has_key(m, cur)
    var binding = m[cur]
    Exit(ctx)
    Engine.RunBinding(ctx, binding)
    return
  endif
  var hasPrefix = false
  for seq in order
    if strpart(seq, 0, len(cur)) == cur
      hasPrefix = true
      break
    endif
  endfor
  if !hasPrefix
    Exit(ctx)
    ctx.ui.Hint('SPC ' .. Spaced(cur) .. ' is undefined')
  else
    ctx.ui.ScheduleWhichKey('keypad', cur)
  endif
enddef
