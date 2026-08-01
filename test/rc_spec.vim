vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H
import autoload 'vimeow/core/rc.vim' as Rc
import autoload 'vimeow/core/rcstate.vim' as RcState

H.Describe('RcSpec', () => {
  H.It('given an nmap line then the key resolves to its target', () => {
    H.FreshSpec()
    var c = Rc.Parse(['nmap Z ,b', 'nmap q meow-cancel-selection'])
    H.Eq(c.errors, [])
    H.Eq(c.normal['Z'].keys, ',b')
    H.Eq(c.normal['q'].command, 'meow-cancel-selection')
  })

  H.It('given an action target then it is kept verbatim for the host', () => {
    H.FreshSpec()
    var c = Rc.Parse(['nmap Q <action>(only)'])
    H.Eq(c.normal['Q'].action, 'only')
  })

  H.It('given a multi-key normal lhs then an error is collected', () => {
    H.FreshSpec()
    var c = Rc.Parse(['nmap ZZ meow-cancel-selection'])
    H.Eq(len(c.errors), 1)
    H.Ok(c.errors[0] =~ 'single printable key', 'error wording')
  })

  H.It('given SPC as a normal lhs then the rc refuses it', () => {
    H.FreshSpec()
    var c = Rc.Parse(['nmap <Space> meow-cancel-selection'])
    H.Eq(len(c.errors), 1)
    H.Ok(c.errors[0] =~ 'keypad key', 'error wording')
  })

  H.It('given a reserved keypad prefix then the rc refuses it', () => {
    H.FreshSpec()
    var c = Rc.Parse(['map <leader>1x meow-cancel-selection'])
    H.Eq(len(c.errors), 1)
    H.Ok(c.errors[0] =~ 'reserved', 'error wording')
  })

  H.It('given a home rc then it layers over the bundled defaults key by key', () => {
    var s = H.FreshSpec()
    s.GivenRc('nmap w meow-mark-symbol')
    H.Eq(Rc.Cfg().normal['w'].command, 'meow-mark-symbol')
    H.Eq(Rc.Defaults().normal['w'].command, 'meow-mark-word')
  })

  H.It('given the bundled rc then the whole NORMAL layout is defined', () => {
    H.FreshSpec()
    var d = Rc.Defaults().normal
    for key in ['h', 'j', 'k', 'l', 'w', 'e', 'b', 'x', 'f', 't', 'o', 'm',
                'i', 'a', 'c', 's', 'd', 'y', 'p', 'r', 'u', 'v', 'n', 'z', 'g']
      H.Ok(has_key(d, key), 'NORMAL key ' .. key .. ' is bound')
    endfor
  })

  H.It('given the bundled rc then MOTION mode binds the list keys', () => {
    H.FreshSpec()
    var m = Rc.Defaults().motion
    H.Eq(m['j'].command, 'meow-next')
    H.Eq(m['k'].command, 'meow-prev')
    H.Eq(m['q'].action, 'close')
  })

  H.It('given the bundled rc then the keypad defines the SPC groups', () => {
    H.FreshSpec()
    var pair = Rc.Keypad()
    var kp = pair[0]
    for seq in ['bb', 'ff', 'xf', 'wh', 'cm', 'cM', 'ss', 'mf']
      H.Ok(has_key(kp, seq), 'keypad SPC ' .. seq .. ' is bound')
    endfor
  })

  H.It('given which-key settings then user lines layer over bundled defaults', () => {
    var s = H.FreshSpec()
    H.Eq(Rc.WhichKeyEnabled(), true)
    H.Eq(Rc.WhichKeyDelayMs(), 300)
    s.GivenRc("set nowhich-key\nset timeoutlen=150")
    H.Eq(Rc.WhichKeyEnabled(), false)
    H.Eq(Rc.WhichKeyDelayMs(), 150)
  })

  H.It('given colour settings then they layer over the bundled default', () => {
    var s = H.FreshSpec()
    H.Eq(Rc.OverlayColor(), '#2ecc71')
    H.Eq(Rc.GrabColor(), '#cde8cd')
    s.GivenRc("set overlay-color=#010203\nset grab-color=#040506")
    H.Eq(Rc.OverlayColor(), '#010203')
    H.Eq(Rc.GrabColor(), '#040506')
  })

  H.It('given an invalid colour then an error is collected', () => {
    H.FreshSpec()
    var c = Rc.Parse(['set overlay-color=#12345', 'set grab-color=nope'])
    H.Eq(len(c.errors), 2)
    H.Eq(c.overlayColor, '')
  })

  H.It('given a repeat line then the group holds its member targets', () => {
    H.FreshSpec()
    var c = Rc.Parse(['repeat nav . meow-next', 'repeat nav , meow-prev'])
    H.Eq(c.errors, [])
    H.Eq(c.repeatGroups['nav'].map['.'].command, 'meow-next')
    H.Eq(c.repeatGroups['nav'].map[','].command, 'meow-prev')
  })

  H.It('given a repeat member bound to ignore then the key is given back', () => {
    var s = H.FreshSpec()
    s.GivenRc('repeat zoom 0 ignore')
    var groups = Rc.RepeatGroups()[0]
    H.Ok(!has_key(groups['zoom'].map, '0'), 'zoom 0 handed back')
    H.Eq(groups['zoom'].map['i'].action, 'resize +2')
  })

  H.It('given the bundled rc then the init el repeat groups are declared', () => {
    H.FreshSpec()
    var d = Rc.Defaults().repeatGroups
    for group in ['zoom', 'qf', 'buf', 'replay']
      H.Ok(has_key(d, group), 'repeat group ' .. group)
    endfor
  })

  H.It('given the ideavimrc WhichKeyDesc let syntax then descriptions parse', () => {
    H.FreshSpec()
    var c = Rc.Parse(['let g:WhichKeyDesc_leader_x = "<leader>x C-x files/buffers"'])
    H.Eq(c.keypadDesc['x'], 'C-x files/buffers')
    H.Eq(c.errors, [])
  })

  H.It('given a cmap or cnoremap line then the rc binds the chord', () => {
    H.FreshSpec()
    var c = Rc.Parse(['cmap control F forward-char', 'cnoremap alt D kill-word', 'nmap Z ,b'])
    H.Eq(c.errors, [])
    H.Eq(len(c.normal), 1, 'cmap and cnoremap add no normal bindings')
    H.Eq(len(c.chords), 2, 'they land in the chord map instead')
  })

  H.It('given a vim option set line then it is ignored without error', () => {
    H.FreshSpec()
    var c = Rc.Parse(['set clipboard+=unnamedplus', 'set ignorecase'])
    H.Eq(c.errors, [])
  })

  H.It('given comment-only rc edits then the reload reports no changes', () => {
    H.FreshSpec()
    Rc.SetUserLines(['nmap Z ,b'])
    H.Ok(RcState.EqualTo(Rc.Parse(['" just a comment', 'nmap Z ,b'])), 'unchanged')
    H.Ok(!RcState.EqualTo(Rc.Parse(['nmap Q meow-goto-line'])), 'changed')
  })

  H.It('given the bundled rc then it parses with no errors at all', () => {
    H.FreshSpec()
    H.Eq(Rc.Defaults().errors, [])
  })
})
