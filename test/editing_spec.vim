vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H
import autoload 'vimeow/core/state.vim' as St

H.Describe('EditingSpec', () => {
  H.It('given a selection when s then it is killed to the clipboard', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenKeys('ws')
    s.ThenText(' world')
    s.ThenClipboard('hello')
  })

  H.It('given a selection when y then it is copied and the caret lands at its end', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenKeys('wy')
    s.ThenText('hello world')
    s.ThenClipboard('hello')
    s.ThenCaretAt(5)
  })

  H.It('given a clipboard when p then it is yanked at point', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>world')
    s.GivenClipboard('hello ')
    s.WhenKeys('p')
    s.ThenText('hello world')
  })

  H.It('given a selection when c then it is replaced and meow enters INSERT', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenKeys('wc')
    s.ThenText(' world')
    s.ThenMode(St.INSERT)
  })

  H.It('given a selection when r then the clipboard replaces it', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.GivenClipboard('goodbye')
    s.WhenKeys('wr')
    s.ThenText('goodbye world')
  })

  H.It('given no selection when d then the char under point goes', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello')
    s.WhenKeys('d')
    s.ThenText('ello')
  })

  H.It('given no selection when D then the char before point goes', () => {
    var s = H.FreshSpec()
    s.Given('word', 'he<caret>llo')
    s.WhenKeys('D')
    s.ThenText('hllo')
  })

  H.It('given i then meow enters INSERT at the selection start', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenKeys('wi')
    s.ThenCaretAt(0)
    s.ThenMode(St.INSERT)
  })

  H.It('given a then meow enters INSERT at the selection end', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenKeys('wa')
    s.ThenCaretAt(5)
    s.ThenMode(St.INSERT)
  })

  H.It('given a read-only document then all motions work and the modify commands are inert', () => {
    var s = H.FreshSpec()
    s.Given('two lines', "<caret>one\ntwo")
    s.GivenReadOnly()
    s.WhenKeys('j')
    H.Eq(s.CaretLine(), 1, 'caret line')
    s.WhenKeys('kw')
    s.ThenSelection('one')
    s.WhenKeys('s')
    s.ThenText("one\ntwo")
    s.ThenSelection('one')
    s.WhenKeys('y')
    s.ThenClipboard('one')
    s.WhenKeys('d')
    s.WhenKeys('p')
    s.ThenText("one\ntwo")
    s.ThenMode(St.NORMAL)
  })

  H.It('given no selection when C-k then the line is killed like Emacs', () => {
    var s = H.FreshSpec()
    s.Given('two lines', "<caret>hello\nworld")
    s.WhenCommand('meow-kill')
    s.ThenText("\nworld")
    s.ThenClipboard('hello')
  })

  H.It('given upcase-word then the word ahead is upcased', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenCommand('upcase-word')
    s.ThenText('HELLO world')
  })

  H.It('given capitalize-word then only the first letter is raised', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenCommand('capitalize-word')
    s.ThenText('Hello world')
  })

  H.It('given kill-word then the word ahead is killed to the clipboard', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenCommand('kill-word')
    s.ThenText(' world')
    s.ThenClipboard('hello')
  })

  H.It('given open-line then the line breaks and point stays before the newline', () => {
    var s = H.FreshSpec()
    s.Given('word', 'hel<caret>lo')
    s.WhenCommand('open-line')
    s.ThenText("hel\nlo")
    s.ThenCaretAt(3)
  })

  H.It('given just-one-space then the run of blanks collapses to one', () => {
    var s = H.FreshSpec()
    s.Given('blanks', 'a   <caret>   b')
    s.WhenCommand('just-one-space')
    s.ThenText('a b')
  })

  H.It('given delete-horizontal-space then the blanks on both sides go', () => {
    var s = H.FreshSpec()
    s.Given('blanks', 'a   <caret>   b')
    s.WhenCommand('delete-horizontal-space')
    s.ThenText('ab')
  })

  H.It('given m then the join region is selected and killing it joins the lines', () => {
    var s = H.FreshSpec()
    s.Given('two lines', "one\n  <caret>two")
    s.WhenKeys('m')
    s.ThenSelType(St.SEL_JOIN)
    s.WhenKeys('s')
    s.ThenText('one two')
  })

  H.It('given u then undo runs on the port', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello')
    s.WhenKeys('u')
    H.Eq(s.editor.undoCount, 1, 'undo count')
  })
})
