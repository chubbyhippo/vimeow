vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H

H.Describe('GrabBeaconSpec', () => {
  H.It('given a selection when G then it becomes the grab and the selection is cancelled', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello world')
    s.WhenKeys('wG')
    s.ThenNoSelection()
    H.Eq(s.state.grab.start, 0)
    H.Eq(s.state.grab.stop, 5)
  })

  H.It('given a grab then the highlight paints its range', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello world')
    s.WhenKeys('wG')
    H.Neq(s.ui.grab, null_object, 'grab highlight painted')
    H.Eq(s.ui.grab.start, 0)
    H.Eq(s.ui.grab.end, 5)
  })

  H.It('given the grab is cancelled then the highlight clears', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello world')
    s.WhenKeys('wG')
    H.Neq(s.ui.grab, null_object, 'painted')
    s.WhenKeys('G')
    H.Eq(s.ui.grab, null_object, 'cleared')
  })

  H.It('given no selection when G then an existing grab is cancelled', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello world')
    s.WhenKeys('wG')
    H.Ok(s.state.HasGrab(), 'grab set')
    s.WhenKeys('G')
    H.Ok(!s.state.HasGrab(), 'grab cleared')
  })

  H.It('given a grab and a selection elsewhere when R then the two texts swap', () => {
    var s = H.FreshSpec()
    s.Given('three words', '<caret>one two three')
    s.WhenKeys('wG')
    s.GivenCaretAt(8)
    s.WhenKeys('w')
    s.ThenSelection('three')
    s.WhenKeys('R')
    s.ThenText('three two one')
  })

  H.It('given no grab when R then nothing changes', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello')
    s.WhenKeys('wR')
    s.ThenText('hello')
    H.Ok(index(s.ui.hints, 'No grab') >= 0, 'no-grab hint')
  })

  H.It('given Y then the grab is re-synced to the current selection', () => {
    var s = H.FreshSpec()
    s.Given('three words', '<caret>one two three')
    s.WhenKeys('wG')
    s.GivenCaretAt(4)
    s.WhenKeys('wY')
    H.Eq(s.state.grab.start, 4)
    H.Eq(s.state.grab.stop, 7)
  })

  H.It('given a grab when z then the grab pops back as a selection', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello world')
    s.WhenKeys('wG')
    s.WhenKeys('z')
    s.ThenSelection('hello')
  })

  H.It('given a grab when a word inside it is selected then a caret lands on every match', () => {
    var s = H.FreshSpec()
    s.Given('repeats', '<caret>aa bb aa bb')
    s.WhenKeys('.bG')
    s.GivenCaretAt(0)
    s.WhenKeys('w')
    H.Ok(len(s.editor.sels) > 1, 'beacon carets appeared')
  })

  H.It('given a grab when x inside it then a caret lands on every line', () => {
    var s = H.FreshSpec()
    s.Given('three lines', "<caret>one\ntwo\nthree")
    s.WhenKeys('.bG')
    s.GivenCaretAt(0)
    s.WhenKeys('x')
    H.Eq(len(s.editor.sels), 3, 'one caret per line')
  })

  H.It('given a selection outside the grab then no beacon carets appear', () => {
    var s = H.FreshSpec()
    s.Given('words', '<caret>aa bb cc')
    s.WhenKeys('wG')
    s.GivenCaretAt(6)
    s.WhenKeys('w')
    s.ThenCaretCount(1)
  })
})
