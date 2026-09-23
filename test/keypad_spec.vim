vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H
import autoload 'vimeow/core/state.vim' as St
import autoload 'vimeow/core/engine.vim' as Engine
import autoload 'vimeow/core/whichkey.vim' as WhichKey

H.Describe('ModesKeypadSpec', () => {
  H.It('given SPC then KEYPAD opens and a digit becomes the count for the next command', () => {
    var s = H.FreshSpec()
    s.Given('four lines', "<caret>one\ntwo\nthree\nfour")
    s.WhenKeys(' ')
    s.ThenMode(St.KEYPAD)
    s.WhenKeys('2')
    s.ThenMode(St.NORMAL)
    s.WhenKeys('j')
    H.Eq(s.CaretLine(), 2, 'caret line')
  })

  H.It('given SPC x then the keypad keeps collecting the prefix', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello')
    s.WhenKeys(' x')
    s.ThenMode(St.KEYPAD)
    H.Eq(s.state.keypad, 'x', 'keypad buffer')
  })

  H.It('given a keypad action entry then the host command runs', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello')
    s.WhenKeys(' x1')
    s.ThenMode(St.NORMAL)
    H.Eq(s.ui.ran[-1], 'only', 'ran host command')
  })

  H.It('given a keypad meow entry then the meow command runs', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenKeys(' mf')
    s.ThenMode(St.NORMAL)
    s.ThenCaretAt(5)
  })

  H.It('given an undefined keypad sequence then KEYPAD exits back to NORMAL', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello')
    s.WhenKeys(' Z')
    s.ThenMode(St.NORMAL)
    H.Ok(s.ui.hints[-1] =~ 'undefined', 'undefined hint')
  })

  H.It('given KEYPAD when escape then back to NORMAL without dispatch', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello')
    s.WhenKeys(' ')
    s.ThenMode(St.KEYPAD)
    H.Eq(s.PressEsc(), true)
    s.ThenMode(St.NORMAL)
    s.ThenText('hello')
  })

  H.It('given SPC question mark then the cheatsheet is shown', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello')
    s.WhenKeys(' ?')
    s.ThenMode(St.NORMAL)
    H.Eq(s.ui.infos[-1][0], 'Meow Cheatsheet', 'cheatsheet title')
  })

  H.It('given SPC slash and a key then describe lists what it runs', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello')
    s.WhenKeys(' /w')
    s.ThenMode(St.NORMAL)
    H.Ok(s.ui.infos[-1][0] =~ 'Describe', 'describe title')
    H.Ok(s.ui.infos[-1][1] =~ 'ace-window', 'describe body lists the window group')
  })

  H.It('given INSERT when the keypad action fires then a keypad command returns to INSERT', () => {
    var s = H.FreshSpec()
    s.Given('two words', '<caret>hello world')
    s.WhenKeys('i')
    s.ThenMode(St.INSERT)
    Engine.EnterKeypad(s.Ctx())
    s.ThenMode(St.KEYPAD)
    H.Eq(s.state.keypadPreviousState, St.INSERT, 'keypad remembers INSERT')
    s.WhenKeys('mf')
    s.ThenMode(St.INSERT)
  })

  H.It('given INSERT when the keypad action then escape then back to INSERT', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello')
    s.WhenKeys('i')
    Engine.EnterKeypad(s.Ctx())
    H.Eq(s.PressEsc(), true)
    s.ThenMode(St.INSERT)
  })

  H.It('given NORMAL when the keypad action fires then KEYPAD round-trips to NORMAL', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello')
    Engine.EnterKeypad(s.Ctx())
    s.ThenMode(St.KEYPAD)
    H.Eq(s.PressEsc(), true)
    s.ThenMode(St.NORMAL)
  })

  H.It('given the which-key rows then they list the child keys of the prefix', () => {
    H.FreshSpec()
    var rows = WhichKey.KeypadRows('w')
    H.Ok(len(rows) > 0, 'rows for SPC w')
    var keys: list<string> = []
    for r in rows
      add(keys, r[0])
    endfor
    for want in ['h', 'j', 'k', 'l', 'w', 'r']
      H.Ok(index(keys, want) >= 0, 'SPC w ' .. want .. ' listed')
    endfor
  })

  H.It('given the things which-key table then it names all fourteen things', () => {
    H.Eq(len(WhichKey.THINGS), 14)
    H.Eq(WhichKey.THINGS[0], ['r', 'round ( )'])
  })

  H.It('given a repeat run then the member keys keep walking and any other key ends it', () => {
    var s = H.FreshSpec()
    s.Given('word', '<caret>hello')
    s.WhenKeys(' wi')
    H.Neq(Engine.repeatMap, {}, 'run armed')
    s.WhenKeys('i')
    H.Eq(s.ui.ran[-1], 'resize +2', 'member key repeated')
    s.WhenKeys('w')
    H.Eq(Engine.repeatMap, {}, 'run ended')
    s.ThenSelection('hello')
  })
})
