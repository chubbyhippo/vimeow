vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H
import autoload 'vimeow/core/state.vim' as St

H.Describe('MovementSpec', () => {
  H.It('given no selection when h or l then the caret moves without selecting', () => {
    var s = H.FreshSpec()
    s.Given('plain text', '<caret>hello')
    s.WhenCommand('meow-right')
    s.ThenCaretAt(1)
    s.ThenNoSelection()
    s.WhenCommand('meow-left')
    s.ThenCaretAt(0)
  })

  H.It('given a count when j then the caret moves that many lines', () => {
    var s = H.FreshSpec()
    s.Given("four lines", "<caret>one\ntwo\nthree\nfour")
    s.WhenKeys('2j')
    H.Eq(s.CaretLine(), 2, 'caret line')
  })

  H.It('given H then the char selection extends left', () => {
    var s = H.FreshSpec()
    s.Given('plain text', 'hello<caret> world')
    s.WhenCommand('meow-left-expand')
    s.ThenSelection('o')
    s.ThenSelType(St.SEL_CHAR)
  })

  H.It('given a word then w marks it and e moves to the next end', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenCommand('meow-mark-word')
    s.ThenSelection('hello')
    s.ThenSelType(St.SEL_WORD)
  })

  H.It('given the caret mid-buffer then next-word selects to the following end', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenCommand('meow-next-word')
    s.ThenSelection('hello')
  })

  H.It('given back-word then the selection runs backward', () => {
    var s = H.FreshSpec()
    s.Given('two words', 'hello world<caret>')
    s.WhenCommand('meow-back-word')
    s.ThenSelection('world')
  })

  H.It('given x then the whole line is selected', () => {
    var s = H.FreshSpec()
    s.Given("two lines", "<caret>one two\nthree")
    s.WhenCommand('meow-line')
    s.ThenSelection('one two')
    s.ThenSelType(St.SEL_LINE)
  })

  H.It('given f and a char then the selection runs to it inclusive', () => {
    var s = H.FreshSpec()
    s.Given('letters', '<caret>abcabc')
    s.WhenKeys('fc')
    s.ThenSelection('abc')
    s.ThenSelType(St.SEL_FIND)
  })

  H.It('given t and a char then the selection stops before it', () => {
    var s = H.FreshSpec()
    s.Given('letters', '<caret>abcabc')
    s.WhenKeys('tc')
    s.ThenSelection('ab')
    s.ThenSelType(St.SEL_TILL)
  })

  H.It('given move-end-of-line then the caret lands at the line end', () => {
    var s = H.FreshSpec()
    s.Given("two lines", "<caret>hello\nworld")
    s.WhenCommand('move-end-of-line')
    s.ThenCaretAt(5)
  })

  H.It('given back-to-indentation then the caret lands on the first real char', () => {
    var s = H.FreshSpec()
    s.Given('indented', '    hel<caret>lo')
    s.WhenCommand('back-to-indentation')
    s.ThenCaretAt(4)
  })

  H.It('given beginning-of-buffer then the caret goes to the top', () => {
    var s = H.FreshSpec()
    s.Given("two lines", "one\ntw<caret>o")
    s.WhenCommand('beginning-of-buffer')
    s.ThenCaretAt(0)
  })

  H.It('given a negative argument then the motion reverses', () => {
    var s = H.FreshSpec()
    s.Given('two words', 'hello world<caret>')
    s.WhenKeys('-')
    s.WhenCommand('meow-next-word')
    s.ThenSelection('world')
  })
})
