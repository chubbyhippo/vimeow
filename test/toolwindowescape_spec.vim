vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H
import autoload 'vimeow/core/state.vim' as St
import autoload 'vimeow/core/engine.vim' as Engine
import autoload 'vimeow/core/toolwindowescape.vim' as TWE

const NAV_RC = "map <leader>tn meow-next\nrepeat nav . meow-next\nrepeat nav , meow-prev"

H.Describe('ToolWindowEscapeSpec', () => {
  H.It('given a single escape in a tool window then it does not jump', () => {
    TWE.Reset()
    H.Eq(TWE.OnEscape('terminal', 1000), false)
  })

  H.It('given a second escape in the same tool window within the timeout then it jumps', () => {
    TWE.Reset()
    TWE.OnEscape('terminal', 1000)
    H.Eq(TWE.OnEscape('terminal', 1000 + TWE.TIMEOUT_MS), true)
  })

  H.It('given a completed jump then the next escape starts a new pair', () => {
    TWE.Reset()
    TWE.OnEscape('terminal', 1000)
    H.Eq(TWE.OnEscape('terminal', 1100), true)
    H.Eq(TWE.OnEscape('terminal', 1200), false)
  })

  H.It('given escapes slower than the timeout then they do not pair but re-arm', () => {
    TWE.Reset()
    TWE.OnEscape('terminal', 1000)
    H.Eq(TWE.OnEscape('terminal', 1001 + TWE.TIMEOUT_MS), false)
    H.Eq(TWE.OnEscape('terminal', 1200 + TWE.TIMEOUT_MS), true)
  })

  H.It('given escapes in different tool windows then they do not pair', () => {
    TWE.Reset()
    TWE.OnEscape('terminal', 1000)
    H.Eq(TWE.OnEscape('list', 1100), false)
    H.Eq(TWE.OnEscape('list', 1200), true)
  })

  H.It('given focus outside any tool window then the pair breaks', () => {
    TWE.Reset()
    TWE.OnEscape('terminal', 1000)
    H.Eq(TWE.OnEscape('', 1100), false)
    H.Eq(TWE.OnEscape('terminal', 1200), false)
  })

  H.It("given KEYPAD then escape is meow's and exits the keypad", () => {
    var s = H.FreshSpec()
    s.Given('keypad escape', '<caret>hello')
    s.WhenKeys(' ')
    s.ThenMode(St.KEYPAD)
    H.Eq(s.PressEsc(), true)
    s.ThenMode(St.NORMAL)
  })

  H.It("given an active selection then escape is meow's and clears it", () => {
    var s = H.FreshSpec()
    s.Given('selection escape', '<caret>hello world')
    s.WhenKeys('w')
    H.Neq(s.SelectedText(), '', 'has a selection')
    H.Eq(s.PressEsc(), true)
    H.Eq(s.SelectedText(), '', 'selection cleared')
  })

  H.It("given an armed repeat run then escape is meow's and ends it", () => {
    var s = H.FreshSpec()
    s.Given('four lines', "<caret>one\ntwo\nthree\nfour")
    s.GivenRc(NAV_RC)
    s.WhenKeys(' tn')
    H.Neq(Engine.repeatMap, {}, 'run armed')
    H.Eq(s.PressEsc(), true)
    H.Eq(Engine.repeatMap, {}, 'run ended')
  })

  H.It("given NORMAL with nothing to cancel then escape is not meow's", () => {
    var s = H.FreshSpec()
    s.Given('idle escape', '<caret>hello')
    H.Eq(s.PressEsc(), false)
  })

  H.It("given INSERT then escape is meow's and returns to NORMAL", () => {
    var s = H.FreshSpec()
    s.Given('insert escape', '<caret>hello')
    s.WhenKeys('i')
    s.ThenMode(St.INSERT)
    H.Eq(s.PressEsc(), true)
    s.ThenMode(St.NORMAL)
  })
})
