vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import autoload 'vimeow/core.vim' as Core
import autoload 'vimeow/defaultrc.vim' as DefaultRc
import autoload 'vimeow/core/state.vim' as St
import autoload 'vimeow/core/port.vim' as P
import autoload 'vimeow/core/rc.vim' as Rc
import autoload 'vimeow/core/registry.vim' as Registry
import autoload 'vimeow/core/engine.vim' as Engine
import autoload 'vimeow/core/text.vim' as T

export var failures: list<string> = []
export var passed: number = 0
export var suiteName: string = ''

export def Describe(name: string, Body: func)
  suiteName = name
  Body()
enddef

export def It(sentence: string, Body: func)
  try
    Body()
    passed += 1
  catch
    add(failures, suiteName .. ' :: ' .. sentence .. "\n      " .. v:exception)
  endtry
enddef

export def Eq(actual: any, expected: any, msg: string = 'value')
  if string(actual) !=# string(expected)
    throw msg .. ': expected ' .. string(expected) .. ', got ' .. string(actual)
  endif
enddef

export def Neq(actual: any, unexpected: any, msg: string = 'value')
  if string(actual) ==# string(unexpected)
    throw msg .. ': did not expect ' .. string(unexpected)
  endif
enddef

export def Ok(cond: bool, msg: string = 'expected true')
  if !cond
    throw msg
  endif
enddef

export class FakeEditor implements P.EditorPort
  public var text: string = ''
  public var sels: list<P.SelRange> = [P.SelRange.new(0, 0)]
  public var writable: bool = true
  public var visible: P.LineRange = null_object
  public var undoCount: number = 0

  def GetText(): string
    return this.text
  enddef

  def GetSelections(): list<P.SelRange>
    var out: list<P.SelRange> = []
    for s in this.sels
      add(out, P.SelRange.new(s.anchor, s.active))
    endfor
    return out
  enddef

  def SetSelections(sels: list<P.SelRange>)
    var out: list<P.SelRange> = []
    for s in sels
      add(out, P.SelRange.new(s.anchor, s.active))
    endfor
    this.sels = out
  enddef

  def Edit(edits: list<P.TextEdit>)
    var sorted = copy(edits)
    sort(sorted, (a, b) => b.start - a.start)
    for e in sorted
      this.text = strpart(this.text, 0, e.start) .. e.text .. strpart(this.text, e.end)
    endfor
  enddef

  def IsWritable(): bool
    return this.writable
  enddef

  def VisibleLineRange(): P.LineRange
    return this.visible
  enddef

  def Undo()
    this.undoCount += 1
  enddef

  def CloseEditor()
  enddef

  def SymbolRangeAt(offset: number): P.OffsetRange
    return null_object
  enddef
endclass

export class FakeClipboard implements P.ClipboardPort
  public var content: string = ''

  def Read(): string
    return this.content
  enddef

  def Write(text: string)
    this.content = text
  enddef
endclass

export class FakeUi implements P.UiPort
  public var hints: list<string> = []
  public var infos: list<list<string>> = []
  public var answers: list<string> = []
  public var ran: list<string> = []
  public var modes: list<string> = []
  public var expandHints: list<number> = []
  public var avyMatches: list<P.OffsetRange> = []
  public var avyLabels: list<P.AvyLabel> = []
  public var grab: P.OffsetRange = null_object
  public var revealed: list<string> = []
  public var timerSeq: number = 0
  public var timers: dict<func> = {}

  def Hint(text: string)
    add(this.hints, text)
  enddef

  def RevealCaret(at: string)
    add(this.revealed, at)
  enddef

  def Info(title: string, body: string)
    add(this.infos, [title, body])
  enddef

  def Input(prompt: string, initial: string): string
    if empty(this.answers)
      return ''
    endif
    return remove(this.answers, 0)
  enddef

  def RunCommand(id: string)
    add(this.ran, id)
  enddef

  def ScheduleWhichKey(kind: string, buffer: string)
  enddef

  def HideWhichKey()
  enddef

  def ShowExpandHints(positions: list<number>)
    this.expandHints = positions
  enddef

  def ClearExpandHints()
    this.expandHints = []
  enddef

  def ShowAvyMatches(matches: list<P.OffsetRange>)
    this.avyMatches = matches
  enddef

  def ShowAvyLabels(labels: list<P.AvyLabel>)
    this.avyLabels = labels
  enddef

  def ClearAvy()
    this.avyMatches = []
    this.avyLabels = []
  enddef

  def SetGrabHighlight(range: P.OffsetRange)
    this.grab = range
  enddef

  def ModeChanged(state: St.MeowState)
    add(this.modes, state.mode)
  enddef

  def Refresh(state: St.MeowState)
  enddef

  def StartTimer(ms: number, Cb: func): number
    this.timerSeq += 1
    this.timers[string(this.timerSeq)] = Cb
    return this.timerSeq
  enddef

  def CancelTimer(id: number)
    if has_key(this.timers, string(id))
      remove(this.timers, string(id))
    endif
  enddef
endclass

export class Spec
  public var editor: FakeEditor
  public var clip: FakeClipboard
  public var ui: FakeUi
  public var state: St.MeowState

  def new()
    this.editor = FakeEditor.new()
    this.clip = FakeClipboard.new()
    this.ui = FakeUi.new()
    this.state = St.NewState()
  enddef

  def Ctx(): P.Ctx
    return P.Ctx.new(this.editor, this.clip, this.ui, this.state)
  enddef

  def Given(description: string, textWithCaret: string)
    var at = stridx(textWithCaret, '<caret>')
    this.editor.text = substitute(textWithCaret, '<caret>', '', '')
    var off = at < 0 ? 0 : at
    this.editor.sels = [P.SelRange.new(off, off)]
    this.state = St.NewState()
  enddef

  def GivenRc(text: string)
    Rc.SetForTest(Rc.Parse(split(text, "\n", true)))
  enddef

  def GivenClipboard(text: string)
    this.clip.content = text
  enddef

  def GivenCaretAt(offset: number)
    this.editor.sels = [P.SelRange.new(offset, offset)]
  enddef

  def GivenReadOnly()
    this.editor.writable = false
  enddef

  def GivenAnswers(answers: list<string>)
    this.ui.answers = copy(answers)
  enddef

  def WhenKeys(keys: string)
    for i in range(len(keys))
      Engine.HandleChar(this.Ctx(), keys[i])
    endfor
  enddef

  def WhenCommand(name: string)
    if !Registry.Has(name)
      throw 'unknown command: ' .. name
    endif
    Registry.COMMANDS[name](this.Ctx())
  enddef

  def PressEsc(): bool
    return Engine.EscapeKey(this.Ctx())
  enddef

  def SelectedText(): string
    var s = this.editor.sels[0]
    if s.anchor == s.active
      return ''
    endif
    return T.Slice(this.editor.text, s.SelStart(), s.SelEnd())
  enddef

  def CaretLine(): number
    return T.LineOfOffset(this.editor.text, this.editor.sels[0].active)
  enddef

  def ThenSelection(expected: string)
    Eq(this.SelectedText(), expected, 'selected text')
  enddef

  def ThenNoSelection()
    Ok(this.editor.sels[0].anchor == this.editor.sels[0].active, 'expected no selection')
  enddef

  def ThenCaretAt(offset: number)
    Eq(this.editor.sels[0].active, offset, 'caret offset')
  enddef

  def ThenText(expected: string)
    Eq(this.editor.text, expected, 'buffer text')
  enddef

  def ThenMode(expected: string)
    Eq(this.state.mode, expected, 'meow mode')
  enddef

  def ThenSelType(expected: string)
    Eq(this.state.selType, expected, 'selection type')
  enddef

  def ThenClipboard(expected: string)
    Eq(this.clip.content, expected, 'clipboard')
  enddef

  def ThenCaretCount(expected: number)
    Eq(len(this.editor.sels), expected, 'caret count')
  enddef
endclass

export def FreshSpec(): Spec
  Core.Init()
  Rc.InitDefaults(DefaultRc.LINES)
  Rc.SetForTest(Rc.NewConfig())
  Engine.ClearRepeat()
  return Spec.new()
enddef
