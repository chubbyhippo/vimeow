vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H

H.Describe('ThingsSpec', () => {
  H.It('given round brackets then inner selects between them and bounds includes them', () => {
    var s = H.FreshSpec()
    s.Given('call', 'f(ab<caret>c)')
    s.WhenKeys(',r')
    s.ThenSelection('abc')
    s.Given('call', 'f(ab<caret>c)')
    s.WhenKeys('.r')
    s.ThenSelection('(abc)')
  })

  H.It('given square brackets then s is the thing key', () => {
    var s = H.FreshSpec()
    s.Given('index', 'a[i<caret>j]')
    s.WhenKeys(',s')
    s.ThenSelection('ij')
  })

  H.It('given curly brackets then c is the thing key', () => {
    var s = H.FreshSpec()
    s.Given('block', 'x{y<caret>z}')
    s.WhenKeys(',c')
    s.ThenSelection('yz')
  })

  H.It('given a string then g selects inside the quotes', () => {
    var s = H.FreshSpec()
    s.Given('string', 'a = "he<caret>llo"')
    s.WhenKeys(',g')
    s.ThenSelection('hello')
  })

  H.It('given a symbol then e selects it', () => {
    var s = H.FreshSpec()
    s.Given('symbol', 'foo_<caret>bar baz')
    s.WhenKeys(',e')
    s.ThenSelection('foo_bar')
  })

  H.It('given the buffer thing then b selects everything', () => {
    var s = H.FreshSpec()
    s.Given('two lines', "one\ntw<caret>o")
    s.WhenKeys(',b')
    s.ThenSelection("one\ntwo")
  })

  H.It('given a line thing then l selects the line', () => {
    var s = H.FreshSpec()
    s.Given('two lines', "on<caret>e\ntwo")
    s.WhenKeys(',l')
    s.ThenSelection('one')
  })

  H.It('given a paragraph then p selects it', () => {
    var s = H.FreshSpec()
    s.Given('paragraphs', "a\nb<caret>\n\nc")
    s.WhenKeys(',p')
    s.ThenSelection("a\nb")
  })

  H.It('given a sentence then the period thing selects it', () => {
    var s = H.FreshSpec()
    s.Given('sentences', 'One. Tw<caret>o. Three.')
    s.WhenKeys(',.')
    s.ThenSelection('Two.')
  })

  H.It('given the beginning of a thing then the selection runs back to it', () => {
    var s = H.FreshSpec()
    s.Given('call', 'f(ab<caret>c)')
    s.WhenKeys('[r')
    s.ThenSelection('ab')
  })

  H.It('given the end of a thing then the selection runs forward to it', () => {
    var s = H.FreshSpec()
    s.Given('call', 'f(a<caret>bc)')
    s.WhenKeys(']r')
    s.ThenSelection('bc')
  })

  H.It('given no such thing here then meow says so', () => {
    var s = H.FreshSpec()
    s.Given('plain', 'no brackets<caret>')
    s.WhenKeys(',r')
    H.Ok(len(s.ui.hints) > 0, 'a hint was shown')
  })

  H.It('given an enclosing block then o selects it', () => {
    var s = H.FreshSpec()
    s.Given('nested', 'a(b[c<caret>d]e)')
    s.WhenKeys('o')
    s.ThenSelection('[cd]')
  })

  H.It('given slash or question delimiters then comma or dot selects inner and bounds', () => {
    var s = H.FreshSpec()
    s.Given('slash pair', 'val regex = /foo\/b<caret>ar/g')
    s.WhenKeys(',/')
    s.ThenSelection('foo\/bar')
    s.ThenSelType('TRANSIENT')

    s.Given('slash pair', 'val regex = /foo\/b<caret>ar/g')
    s.WhenKeys('./')
    s.ThenSelection('/foo\/bar/')

    s.Given('slash pair', 'val regex = /foo\/b<caret>ar/g')
    s.WhenKeys('[/')
    s.ThenSelection('foo\/b')

    s.Given('slash pair', 'val regex = /foo\/b<caret>ar/g')
    s.WhenKeys(']/')
    s.ThenSelection('ar')

    s.Given('question pair', 'pattern ?foo\?b<caret>ar? flag')
    s.WhenKeys(',?')
    s.ThenSelection('foo\?bar')
    s.ThenSelType('TRANSIENT')

    s.Given('question pair', 'pattern ?foo\?b<caret>ar? flag')
    s.WhenKeys('.?')
    s.ThenSelection('?foo\?bar?')
  })

  H.It('given a url with a double slash then comma slash selects between the surrounding slashes', () => {
    var s = H.FreshSpec()
    s.Given('url with double slash', 'http://mav<caret>en.apache.org/POM/4.0.0')
    s.WhenKeys(',/')
    s.ThenSelection('maven.apache.org')
    s.ThenSelType('TRANSIENT')

    s.Given('url with double slash', 'http://maven.apache.org/PO<caret>M/4.0.0')
    s.WhenKeys(',/')
    s.ThenSelection('POM')
    s.ThenSelType('TRANSIENT')
  })
})
