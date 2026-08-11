vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H
import autoload 'vimeow/core/chord.vim' as Chord
import autoload 'vimeow/core/chords.vim' as Chords
import autoload 'vimeow/core/rc.vim' as Rc
import autoload 'vimeow/core/state.vim' as St

def TargetOf(spelling: string): string
  var b = Chords.BindingFor(Chord.Parse(spelling))
  if empty(b)
    return ''
  endif
  return get(b, 'command', get(b, 'action', get(b, 'keys', '')))
enddef

H.Describe('ChordSpec', () => {
  H.It('given the host spelling then it normalizes to the same chord as the Emacs one', () => {
    H.Eq(Chord.KeyOf('control F'), Chord.KeyOf('C-f'))
    H.Eq(Chord.KeyOf('alt B'), Chord.KeyOf('M-b'))
    H.Eq(Chord.KeyOf('control alt X'), Chord.KeyOf('C-M-x'))
    H.Eq(Chord.Parse('control F').shift, false)
    H.Eq(Chord.Parse('C-F').shift, true)
  })

  H.It('given the Vim spelling then it normalizes to the same chord as the Emacs one', () => {
    H.Eq(Chord.KeyOf('<C-f>'), Chord.KeyOf('C-f'))
    H.Eq(Chord.KeyOf('<M-b>'), Chord.KeyOf('M-b'))
    H.Eq(Chord.KeyOf('<A-b>'), Chord.KeyOf('M-b'))
    H.Eq(Chord.KeyOf('<M-lt>'), Chord.KeyOf('M-<'))
  })

  H.It('given SPC or TAB as the key name then the chord parses like Emacs writes it', () => {
    H.Eq(Chord.Parse('M-SPC').key, ' ')
    H.Eq(Chord.KeyOf('M-SPC'), Chord.KeyOf('alt SPACE'))
    H.Eq(Chord.Parse('C-TAB').key, "\t")
    H.Eq(Chord.Parse('SPC'), {})
  })

  H.It('given a cmap line then it parses into a chord binding', () => {
    H.FreshSpec()
    var c = Rc.Parse(['cmap control F forward-char'])
    H.Eq(c.errors, [])
    H.Eq(c.chords['C-f'].command, 'forward-char')
  })

  H.It('given a cmap with no modifier or a bad keystroke then errors are collected', () => {
    var c = Rc.Parse(['cmap kj forward-char', 'cmap control forward-char'])
    H.Eq(len(c.errors), 2)
    H.Ok(c.errors[0] =~ 'not a chord', 'first error')
    H.Ok(c.errors[1] =~ 'not a chord', 'second error')
    H.Eq(c.chords, {})
  })

  H.It('given the bundled defaults then the whole Emacs chord layer resolves', () => {
    H.FreshSpec()
    H.Eq(TargetOf('C-f'), 'forward-char')
    H.Eq(TargetOf('C-b'), 'backward-char')
    H.Eq(TargetOf('C-n'), 'next-line')
    H.Eq(TargetOf('C-p'), 'previous-line')
    H.Eq(TargetOf('C-a'), 'move-beginning-of-line')
    H.Eq(TargetOf('C-e'), 'move-end-of-line')
    H.Eq(TargetOf('M-f'), 'forward-word')
    H.Eq(TargetOf('M-b'), 'backward-word')
    H.Eq(TargetOf('M-a'), 'backward-sentence')
    H.Eq(TargetOf('M-e'), 'forward-sentence')
    H.Eq(TargetOf('M-<'), 'beginning-of-buffer')
    H.Eq(TargetOf('M->'), 'end-of-buffer')
    H.Eq(TargetOf('M-{'), 'backward-paragraph')
    H.Eq(TargetOf('M-}'), 'forward-paragraph')
    H.Eq(TargetOf('M-u'), 'upcase-word')
    H.Eq(TargetOf('M-l'), 'downcase-word')
    H.Eq(TargetOf('M-c'), 'capitalize-word')
    H.Eq(TargetOf('M-d'), 'kill-word')
    H.Eq(len(Rc.ChordOrder()), 34)
  })

  H.It('given the bundled defaults then the ported tranche-2 chords resolve to their verified action ids', () => {
    H.FreshSpec()
    H.Eq(TargetOf('C-s'), "call feedkeys('/')")
    H.Eq(TargetOf('C-r'), "call feedkeys('?')")
    H.Eq(TargetOf('M-;'), 'VimeowAceWindow')
  })

  H.It('given the bundled defaults then the stock Emacs edit chords resolve', () => {
    H.FreshSpec()
    H.Eq(TargetOf('C-/'), 'meow-undo')
    H.Eq(TargetOf('C-_'), 'meow-undo')
    H.Eq(TargetOf('C-d'), 'meow-delete')
    H.Eq(TargetOf('C-k'), 'meow-kill')
    H.Eq(TargetOf('C-w'), 'meow-kill')
    H.Eq(TargetOf('M-w'), 'meow-save')
    H.Eq(TargetOf('C-y'), 'meow-yank')
    H.Eq(TargetOf('C-g'), 'meow-cancel-selection')
  })

  H.It('given the bundled defaults then the whitespace and line chords resolve', () => {
    H.FreshSpec()
    H.Eq(TargetOf('C-l'), 'recenter-top-bottom')
    H.Eq(TargetOf('M-m'), 'back-to-indentation')
    H.Eq(TargetOf('C-o'), 'open-line')
    H.Eq(TargetOf('M-\'), 'delete-horizontal-space')
    H.Eq(TargetOf('M-SPC'), 'just-one-space')
    H.Eq(TargetOf('M-^'), 'ms')
  })

  H.It('given a home cmap override then it wins over the bundled default', () => {
    var s = H.FreshSpec()
    s.GivenRc('cmap C-f end-of-buffer')
    H.Eq(TargetOf('C-f'), 'end-of-buffer')
    H.Eq(TargetOf('C-b'), 'backward-char')
  })

  H.It('given a home cmap ignore then the chord is handed back to the editor', () => {
    var s = H.FreshSpec()
    s.GivenRc('cmap C-f ignore')
    H.Eq(TargetOf('C-f'), '')
    H.Eq(len(Rc.ChordOrder()), 33)
  })

  H.It('given a pressed chord event then bindingFor resolves it and plain keys do not', () => {
    H.FreshSpec()
    H.Neq(Chords.BindingFor(Chord.Parse('C-f')), {})
    H.Eq(Chords.BindingFor(Chord.Parse('f')), {})
    H.Eq(Chords.BindingFor({}), {})
  })

  H.It('given shift alone then it is not a chord but Ctrl and Alt-Shift are', () => {
    H.Eq(Chord.Parse('S-f'), {})
    H.Eq(Chord.Parse('shift F'), {})
    H.Neq(Chord.Parse('C-f'), {})
    H.Neq(Chord.Parse('alt shift E'), {})
    H.Eq(Chord.Parse('alt shift E').shift, true)
  })

  H.It('given NORMAL or MOTION then a mapped chord is claimed but INSERT and KEYPAD are not', () => {
    H.FreshSpec()
    H.Eq(Chords.Claims(St.NORMAL, Chord.Parse('C-f')), true)
    H.Eq(Chords.Claims(St.MOTION, Chord.Parse('C-f')), true)
    H.Eq(Chords.Claims(St.INSERT, Chord.Parse('C-f')), false)
    H.Eq(Chords.Claims(St.KEYPAD, Chord.Parse('C-f')), false)
    H.Eq(Chords.Claims(St.NORMAL, Chord.Parse('C-q')), false)
  })

  H.It('given an unmapped chord then it is handed back rather than swallowed', () => {
    var s = H.FreshSpec()
    s.Given('plain text', '<caret>hello')
    H.Eq(Chords.Dispatch(s.Ctx(), Chord.Parse('C-q')), false)
    s.ThenCaretAt(0)
  })

  H.It('given a NORMAL editor then dispatching a chord binding runs its command', () => {
    var s = H.FreshSpec()
    s.Given('plain text', '<caret>hello world')
    H.Eq(Chords.Dispatch(s.Ctx(), Chord.Parse('M-f')), true)
    s.ThenCaretAt(5)
  })

  H.It('given both spellings of a punctuation chord then they collapse to one binding', () => {
    H.FreshSpec()
    var c = Rc.Parse(['cmap M-< beginning-of-buffer', 'cmap alt shift COMMA end-of-buffer'])
    H.Eq(c.errors, [])
    H.Eq(c.chords['M-<'].command, 'end-of-buffer')
    H.Eq(len(c.chordOrder), 1)
  })
})
