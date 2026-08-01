vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H
import autoload 'vimeow/core/state.vim' as St

H.Describe('SelectionSpec', () => {
  H.It('given a word selection when a digit then it expands by that many words', () => {
    var s = H.FreshSpec()
    s.Given('three words', '<caret>one two three')
    s.WhenKeys('w')
    s.ThenSelection('one')
    s.WhenKeys('2')
    s.ThenSelection('one two three')
  })

  H.It('given no selection when a digit then it becomes a count', () => {
    var s = H.FreshSpec()
    s.Given('four lines', "<caret>one\ntwo\nthree\nfour")
    s.WhenKeys('3j')
    H.Eq(s.CaretLine(), 3, 'caret line')
  })

  H.It('given a selection when semicolon then it reverses', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenKeys('w')
    s.ThenCaretAt(5)
    s.WhenKeys(';')
    s.ThenCaretAt(0)
  })

  H.It('given a selection when g then it collapses', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenKeys('wg')
    s.ThenNoSelection()
    s.ThenSelType(St.SEL_NONE)
  })

  H.It('given a previous selection when z then it pops back', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenKeys('w')
    s.ThenSelection('hello')
    s.WhenKeys('x')
    s.ThenSelection('hello world')
    s.WhenKeys('z')
    s.ThenSelection('hello')
  })

  H.It('given a line selection when a digit then it expands by lines', () => {
    var s = H.FreshSpec()
    s.Given('three lines', "<caret>one\ntwo\nthree")
    s.WhenKeys('x')
    s.ThenSelection('one')
    s.WhenKeys('1')
    s.ThenSelection("one\ntwo")
  })

  H.It('given expand hints then they mark the next units', () => {
    var s = H.FreshSpec()
    s.Given('three words', '<caret>one two three')
    s.WhenKeys('w')
    H.Ok(len(s.ui.expandHints) > 0, 'expand hints painted')
  })

  H.It('given a symbol selection then W marks it including underscores', () => {
    var s = H.FreshSpec()
    s.Given('symbol', '<caret>foo_bar baz')
    s.WhenKeys('W')
    s.ThenSelection('foo_bar')
    s.ThenSelType(St.SEL_SYMBOL)
  })
})
