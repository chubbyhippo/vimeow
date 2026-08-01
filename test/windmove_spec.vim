vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H
import autoload 'vimeow/core/acewindow.vim' as Ace
import autoload 'vimeow/core/windmove.vim' as Windmove
import autoload 'vimeow/core/resize.vim' as Resizes
import autoload 'vimeow/core/rc.vim' as Rc

H.Describe('WindmoveSpec', () => {
  H.It('given window rectangles then ace-window orders them left to right then top down', () => {
    H.Eq(Ace.Ordered([{item: 'R', x: 40, y: 0},
                      {item: 'L2', x: 0, y: 12},
                      {item: 'L1', x: 0, y: 0}]), ['L1', 'L2', 'R'])
  })

  H.It('given one two or many windows then ace-window plans self other or labels', () => {
    H.Eq(Ace.Plan(1), Ace.PLAN_NONE)
    H.Eq(Ace.Plan(2), Ace.PLAN_OTHER)
    H.Eq(Ace.Plan(3), Ace.PLAN_LABELS)
    H.Eq(Ace.Plan(9), Ace.PLAN_LABELS)
  })

  H.It('given labelled windows then ace-window labels follow the avy subdivision', () => {
    H.Eq(Ace.Labels(3), ['a', 's', 'd'])
    H.Eq(Ace.Labels(0), [])
  })

  H.It('given a typed prefix then ace-window keeps only the windows still matching', () => {
    H.Eq(Ace.Matches(['a', 's', 'la', 'ls'], 'l'), ['la', 'ls'])
    H.Eq(Ace.Matches(['a', 's', 'la', 'ls'], 'z'), [])
  })

  H.It('given a direction then windmove plans the wincmd focus for it', () => {
    H.Eq(Windmove.Plan('left'), 'wincmd h')
    H.Eq(Windmove.Plan('right'), 'wincmd l')
    H.Eq(Windmove.Plan('up'), 'wincmd k')
    H.Eq(Windmove.Plan('down'), 'wincmd j')
  })

  H.It('given no window in the direction then the message is Emacs verbatim', () => {
    H.Eq(Windmove.NoWindowMessage('left'), 'No window left from selected window')
    H.Eq(Windmove.NoWindowMessage('down'), 'No window down from selected window')
  })

  H.It('given the bundled rc then SPC w hjkl dispatch windmove', () => {
    H.FreshSpec()
    var kp = Rc.Keypad()[0]
    H.Eq(kp['wh'].action, 'VimeowWindmoveLeft')
    H.Eq(kp['wj'].action, 'VimeowWindmoveDown')
    H.Eq(kp['wk'].action, 'VimeowWindmoveUp')
    H.Eq(kp['wl'].action, 'VimeowWindmoveRight')
  })

  H.It('given the bundled rc then SPC w w and SPC x o both arm ace-window', () => {
    H.FreshSpec()
    var kp = Rc.Keypad()[0]
    H.Eq(kp['ww'].action, 'VimeowAceWindow')
    H.Eq(kp['xo'].action, 'VimeowAceWindow')
    H.Eq(kp['wW'].action, 'VimeowAceSwapWindow')
  })

  H.It('given an ace slot then it never falls through to replayed keys', () => {
    H.FreshSpec()
    var kp = Rc.Keypad()[0]
    for slot in ['ww', 'wW', 'xo', 'wr']
      H.Ok(!has_key(kp[slot], 'keys'), 'SPC ' .. slot .. ' is not key-replay')
      H.Ok(has_key(kp[slot], 'action') || has_key(kp[slot], 'command'),
           'SPC ' .. slot .. ' has a real target')
    endfor
  })

  H.It('given the bundled rc then SPC w r opens the ace-resize session', () => {
    H.FreshSpec()
    H.Eq(Rc.Keypad()[0]['wr'].action, 'VimeowAceResize')
  })

  H.It('given the bundled rc then the resize session binds the directional keys', () => {
    H.FreshSpec()
    H.Eq(Rc.ResizeOrder(), ['l', 'h', 'k', 'j', '=', 'm'])
    var m = Rc.ResizeBindings()
    H.Eq(m['l'].action, 'vertical resize +4')
    H.Eq(m['h'].action, 'vertical resize -4')
    H.Eq(m['k'].action, 'resize +2')
    H.Eq(m['j'].action, 'resize -2')
    H.Eq(m['='].action, 'wincmd =')
  })

  H.It('given a resize key bound to ignore then the key leaves the session', () => {
    var s = H.FreshSpec()
    s.GivenRc('resizemap m ignore')
    H.Eq(Rc.ResizeOrder(), ['l', 'h', 'k', 'j', '='])
    H.Eq(Resizes.BindingFor('m'), {})
  })

  H.It('given a resize key then dispatch runs its target and unknown keys end the session', () => {
    var s = H.FreshSpec()
    s.Given('two lines', "<caret>one\ntwo")
    H.Eq(Resizes.Dispatch(s.Ctx(), 'l'), true)
    H.Eq(s.ui.ran[-1], 'vertical resize +4')
    H.Eq(Resizes.Dispatch(s.Ctx(), 'Z'), false)
  })
})
