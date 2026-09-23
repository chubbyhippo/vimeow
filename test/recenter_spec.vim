vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H
import autoload 'vimeow/core/view.vim' as View
import autoload 'vimeow/core/chord.vim' as Chord
import autoload 'vimeow/core/chords.vim' as Chords
import autoload 'vimeow/core/port.vim' as P
import autoload 'vimeow/core/state.vim' as St

const BUFFER = "one\ntwo\nthree<caret>\nfour\nfive\n"

H.Describe('RecenterSpec', () => {
  H.It('given the recenter cycle then the positions follow Emacs recenter-positions', () => {
    H.Eq([View.RecenterPosition(0), View.RecenterPosition(1),
          View.RecenterPosition(2), View.RecenterPosition(3)],
         ['center', 'top', 'bottom', 'center'])
  })

  H.It('given a different previous command then the recenter cycle starts over', () => {
    H.Eq(View.NextRecenterPhase(View.RECENTER_COMMAND, 0), 1)
    H.Eq(View.NextRecenterPhase(View.RECENTER_COMMAND, 2), 3)
    H.Eq(View.NextRecenterPhase('meow-left', 2), 0)
    H.Eq(View.NextRecenterPhase('', 2), 0)
  })

  H.It('given repeated C-l then the view cycles center top bottom like Emacs', () => {
    var s = H.FreshSpec()
    s.Given('a caret mid-buffer', BUFFER)
    for _ in range(4)
      s.WhenCommand(View.RECENTER_COMMAND)
    endfor
    H.Eq(s.ui.revealed, ['center', 'top', 'bottom', 'center'])
  })

  H.It('given a motion between two C-l then the second one centers again', () => {
    var s = H.FreshSpec()
    s.Given('a caret mid-buffer', BUFFER)
    s.WhenCommand(View.RECENTER_COMMAND)
    s.WhenKeys('h')
    s.WhenCommand(View.RECENTER_COMMAND)
    H.Eq(s.ui.revealed, ['center', 'center'])
  })

  H.It('given the bundled rc then C-l runs recenter-top-bottom', () => {
    H.FreshSpec()
    H.Eq(Chords.BindingFor(Chord.Parse('C-l')).command, View.RECENTER_COMMAND)
  })
})

def ManyLines(): string
  var lines: list<string> = []
  for i in range(1, 200)
    add(lines, 'line ' .. i)
  endfor
  return '<caret>' .. join(lines, "\n")
enddef

H.Describe('ScrollSpec', () => {
  H.It('given a multi-line buffer then scroll-up-command pages the caret forward by a screenful', () => {
    var s = H.FreshSpec()
    s.Given('many lines', ManyLines())
    s.editor.visible = P.LineRange.new(0, 19)
    var before = s.CaretLine()
    s.WhenCommand(View.SCROLL_UP_COMMAND)
    H.Ok(s.CaretLine() > before + 1, 'scroll-up-command pages forward by more than one line')
    s.ThenNoSelection()
  })

  H.It('given a multi-line buffer then scroll-down-command pages the caret backward by a screenful', () => {
    var s = H.FreshSpec()
    s.Given('many lines', ManyLines())
    s.editor.visible = P.LineRange.new(0, 19)
    s.WhenCommand(View.SCROLL_UP_COMMAND)
    var afterUp = s.CaretLine()
    s.WhenCommand(View.SCROLL_DOWN_COMMAND)
    H.Ok(s.CaretLine() < afterUp, 'scroll-down-command pages back up')
    s.ThenNoSelection()
  })

  H.It('given an active selection then scroll-up-command extends it instead of replacing it', () => {
    var s = H.FreshSpec()
    s.Given('scroll page chord expand', ManyLines())
    s.editor.visible = P.LineRange.new(0, 19)
    s.editor.sels = [P.SelRange.new(0, 1)]
    s.state.selType = St.SEL_CHAR
    s.WhenCommand(View.SCROLL_UP_COMMAND)
    H.Ok(len(s.SelectedText()) > 1, 'the selection grew instead of collapsing')
  })

  H.It('given no viewport information then scroll-up-command still moves forward', () => {
    var s = H.FreshSpec()
    s.Given('many lines', ManyLines())
    var before = s.CaretLine()
    s.WhenCommand(View.SCROLL_UP_COMMAND)
    H.Ok(s.CaretLine() > before, 'falls back instead of doing nothing')
  })

  H.It('given the bundled rc then C-v and M-v run the scroll page commands', () => {
    H.FreshSpec()
    H.Eq(Chords.BindingFor(Chord.Parse('C-v')).command, View.SCROLL_UP_COMMAND)
    H.Eq(Chords.BindingFor(Chord.Parse('M-v')).command, View.SCROLL_DOWN_COMMAND)
  })
})
