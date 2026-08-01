vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H
import autoload 'vimeow/core/view.vim' as View
import autoload 'vimeow/core/chord.vim' as Chord
import autoload 'vimeow/core/chords.vim' as Chords

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
