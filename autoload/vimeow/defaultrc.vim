vim9script
# Copyright (C) 2026 Chubby Hippo
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# GENERATED from .vimeowrc by scripts/gen_default_rc.sh — do not edit.

export const LINES: list<string> =<< trim END
  " vimeow — the bundled default keymap.
  "
  " This file IS the keymap: no key lives in the plugin's code. Copy it to
  " ~/.vimeowrc and edit; your copy overrides these defaults entry by entry, so
  " you only list what you change. Reload with SPC c M, open yours with SPC c m.
  "
  " Within this file, a later line for the same key wins.
  "
  " Syntax (see the README for the full guide):
  "   nmap <key> <action>(excommand)    NORMAL-mode key -> a Vim ex command
  "   nmap <key> <meow-command>         NORMAL-mode key -> named meow command
  "   nmap <key> <meow keys>            NORMAL-mode key -> replayed meow keys
  "   nnoremap ...                      like nmap, but the RHS resolves through
  "                                     these bundled defaults, skipping user maps
  "   mmap / mnoremap <key> <target>    the same, for MOTION mode (read-only
  "                                     buffers stay NORMAL)
  "   map <leader><seq> <target>        keypad (SPC) entry
  "   desc <leader><seq> <text>         which-key label for an entry or a group
  "   cmap <chord> <target>             an Emacs chord (C-f, M-<, control F)
  "   resizemap <key> <target>          a key inside the SPC w r resize session
  "   set timeoutlen=300                which-key popup delay in ms
  "   set nowhich-key                   turn the which-key popup off
  "   set overlay-color=#RRGGBB         avy/ace label background
  "   set overlay-text-color=#RRGGBB    avy/ace label text
  "   set expand-hint-color=#RRGGBB     0-9 expand-hint badge
  "   set grab-color=#RRGGBB            grab / beacon highlight
  "   repeat <group> <key> <target>     tap-to-continue run (Emacs repeat-mode)
  
  set timeoutlen=300
  set grab-color=#cde8cd
  
  " ============================================================================
  " NORMAL — meow's suggested QWERTY layout
  " ----------------------------------------------------------------------------
  " Selection first, then act. Motions that select set a selection TYPE, and the
  " digits 1-9/0 then expand by that type; with no selection they are a count.
  " ============================================================================
  
  nmap h meow-left
  nmap j meow-next
  nmap k meow-prev
  nmap l meow-right
  nmap H meow-left-expand
  nmap J meow-next-expand
  nmap K meow-prev-expand
  nmap L meow-right-expand
  
  nmap w meow-mark-word
  nmap W meow-mark-symbol
  nmap e meow-next-word
  nmap E meow-next-symbol
  nmap b meow-back-word
  nmap B meow-back-symbol
  
  nmap x meow-line
  nmap f meow-find
  nmap F meow-find-expand
  nmap t meow-till
  nmap T meow-till-expand
  nmap o meow-block
  nmap O meow-to-block
  nmap m meow-join
  
  nmap , meow-inner-of-thing
  nmap . meow-bounds-of-thing
  nmap [ meow-beginning-of-thing
  nmap ] meow-end-of-thing
  
  nmap 0 meow-expand-0
  nmap 1 meow-expand-1
  nmap 2 meow-expand-2
  nmap 3 meow-expand-3
  nmap 4 meow-expand-4
  nmap 5 meow-expand-5
  nmap 6 meow-expand-6
  nmap 7 meow-expand-7
  nmap 8 meow-expand-8
  nmap 9 meow-expand-9
  nmap - meow-negative-argument
  nmap ; meow-reverse
  
  nmap i meow-insert
  nmap a meow-append
  nmap I meow-open-above
  nmap A meow-open-below
  nmap c meow-change
  nmap s meow-kill
  nmap d meow-delete
  nmap D meow-backward-delete
  nmap y meow-save
  nmap p meow-yank
  nmap r meow-replace
  nmap u meow-undo
  nmap U meow-undo-in-selection
  
  nmap v meow-visit
  nmap n meow-search
  nmap z meow-pop-selection
  nmap g meow-cancel-selection
  nmap G meow-grab
  nmap R meow-swap-grab
  nmap Y meow-sync-grab
  nmap S avy-goto-char-timer
  nmap Q meow-goto-line
  nmap X meow-goto-line
  nmap q <action>(close)
  nmap ' repeat
  
  " = maximizes the current window; _ and + stay free, because SPC w r
  " (ace-resize) is the directional answer and a wrong binding is worse than none
  nmap = <action>(only)
  
  " ============================================================================
  " MOTION — read-only and list-like buffers (quickfix, help, netrw)
  " ----------------------------------------------------------------------------
  " meow stays out of the way: j/k/h/l walk the list, q closes it.
  " ============================================================================
  
  mmap j meow-next
  mmap k meow-prev
  mmap h meow-left
  mmap l meow-right
  mmap q <action>(close)
  
  " ============================================================================
  " The keypad (SPC) — Emacs' prefix keymaps
  " ----------------------------------------------------------------------------
  " SPC x = C-x, SPC c = C-c, SPC m = M-. SPC 0-9 is a digit argument, SPC ?
  " the cheatsheet and SPC / describe-key; those four are reserved.
  " ============================================================================
  
  " --- SPC b: buffers -------------------------------------------------------
  desc <leader>b buffers
  map <leader>bb <action>(buffers)
  map <leader>bn <action>(bnext)
  map <leader>bp <action>(bprevious)
  map <leader>bd <action>(bdelete)
  map <leader>bs <action>(write)
  map <leader>br <action>(edit!)
  map <leader>bo <action>(browse oldfiles)
  
  " --- SPC f: files ---------------------------------------------------------
  desc <leader>f files
  map <leader>ff <action>(browse edit)
  map <leader>fs <action>(write)
  map <leader>fS <action>(wall)
  map <leader>fr <action>(browse oldfiles)
  map <leader>fd <action>(Explore)
  map <leader>fy <action>(let @+ = expand('%:p'))
  
  " --- SPC x: the C-x family ------------------------------------------------
  desc <leader>x C-x files/buffers/windows
  map <leader>xf <action>(browse edit)
  map <leader>xs <action>(write)
  map <leader>xS <action>(wall)
  map <leader>xb <action>(buffers)
  map <leader>xk <action>(bdelete)
  map <leader>xo <action>(VimeowAceWindow)
  desc <leader>xo ace-window
  map <leader>x0 <action>(close)
  map <leader>x1 <action>(only)
  map <leader>x2 <action>(split)
  map <leader>x3 <action>(vsplit)
  map <leader>xu <action>(undolist)
  map <leader>xc <action>(confirm qall)
  map <leader>xe <action>(normal! @@)
  map <leader>xq <action>(setlocal readonly!)
  map <leader>xz repeat
  map <leader>xj <action>(jumps)
  map <leader>xg <action>(silent! !git status)
  
  " --- SPC w: windows -------------------------------------------------------
  desc <leader>w windows
  map <leader>wh <action>(VimeowWindmoveLeft)
  map <leader>wj <action>(VimeowWindmoveDown)
  map <leader>wk <action>(VimeowWindmoveUp)
  map <leader>wl <action>(VimeowWindmoveRight)
  map <leader>wH <action>(VimeowWindmoveSwapLeft)
  map <leader>wJ <action>(VimeowWindmoveSwapDown)
  map <leader>wK <action>(VimeowWindmoveSwapUp)
  map <leader>wL <action>(VimeowWindmoveSwapRight)
  map <leader>ws <action>(split)
  map <leader>wv <action>(vsplit)
  map <leader>wd <action>(close)
  map <leader>wD <action>(only)
  map <leader>wm <action>(only)
  map <leader>wM <action>(only)
  desc <leader>wM maximize the window
  map <leader>ww <action>(VimeowAceWindow)
  desc <leader>ww ace-window
  map <leader>wW <action>(VimeowAceSwapWindow)
  desc <leader>wW ace-swap-window
  map <leader>wr <action>(VimeowAceResize)
  desc <leader>wr ace-resize
  map <leader>wb <action>(wincmd =)
  map <leader>wn <action>(bnext)
  map <leader>wp <action>(bprevious)
  map <leader>w. <action>(bnext)
  map <leader>w, <action>(bprevious)
  map <leader>wi <action>(resize +2)
  map <leader>w= <action>(resize +2)
  map <leader>wo <action>(resize -2)
  map <leader>w- <action>(resize -2)
  map <leader>wu <action>(vertical resize +4)
  map <leader>w0 <action>(wincmd =)
  
  " --- SPC c: the C-c family (commands) -------------------------------------
  desc <leader>c commands
  map <leader>cm <action>(VimeowEditRc)
  desc <leader>cm open the ~/.vimeowrc settings file
  map <leader>cM <action>(VimeowReloadRc)
  desc <leader>cM reload the rc
  map <leader>cc <action>(make)
  map <leader>cn <action>(cnext)
  map <leader>cp <action>(cprevious)
  map <leader>cl <action>(copen)
  map <leader>cq <action>(cclose)
  map <leader>cf <action>(normal! gg=G)
  desc <leader>cf reindent the buffer
  map <leader>cd <action>(normal! )
  desc <leader>cd jump to definition (tag)
  map <leader>cr <action>(ilist /)
  desc <leader>cr list references
  map <leader>ck <action>(normal! K)
  desc <leader>ck keywordprg lookup
  map <leader>cs <action>(nohlsearch)
  
  " --- SPC s: search --------------------------------------------------------
  desc <leader>s search
  map <leader>ss <action>(call feedkeys('/'))
  map <leader>sr <action>(call feedkeys(':%s/'))
  map <leader>sg <action>(call feedkeys(':vimgrep //j **/*', 'n'))
  map <leader>sh <action>(call feedkeys(':helpgrep '))
  map <leader>sn <action>(nohlsearch)
  map <leader>sv <action>(VimeowReloadRc)
  
  " --- SPC .: diagnostics / quickfix walk -----------------------------------
  desc <leader>. quickfix
  map <leader>.e <action>(cnext)
  map <leader>.l <action>(copen)
  map <leader>.q <action>(cclose)
  
  " --- SPC m: the M- (meta) layer -------------------------------------------
  desc <leader>m meta
  map <leader>mf forward-word
  map <leader>mb backward-word
  map <leader>ma backward-sentence
  map <leader>me forward-sentence
  map <leader>m< beginning-of-buffer
  map <leader>m> end-of-buffer
  map <leader>m{ backward-paragraph
  map <leader>m} forward-paragraph
  map <leader>mu upcase-word
  map <leader>ml downcase-word
  map <leader>mc capitalize-word
  map <leader>md kill-word
  map <leader>mm back-to-indentation
  map <leader>mq <action>(normal! gqip)
  desc <leader>mq fill paragraph
  map <leader>mx <action>(call feedkeys(':'))
  desc <leader>mx execute an ex command
  map <leader>mw meow-save
  map <leader>mg avy-goto-line
  map <leader>mo avy-goto-char-timer
  
  " --- SPC h: help ----------------------------------------------------------
  desc <leader>h help
  map <leader>hh <action>(help)
  map <leader>hk <action>(call feedkeys(':help '))
  map <leader>hm <action>(messages)
  
  " --- SPC SPC: the other buffer (Emacs C-x b default) ----------------------
  map <leader><Space> <action>(buffer #)
  desc <leader><Space> other buffer
  
  " ============================================================================
  " Repeat runs (Emacs repeat-mode): after the first press, keep tapping the
  " member keys; any other key ends the run and keeps its normal meaning.
  " ============================================================================
  
  repeat zoom i <action>(resize +2)
  repeat zoom = <action>(resize +2)
  repeat zoom o <action>(resize -2)
  repeat zoom - <action>(resize -2)
  repeat zoom u <action>(vertical resize +4)
  repeat zoom 0 <action>(wincmd =)
  
  repeat qf e <action>(cnext)
  repeat qf . <action>(cnext)
  repeat qf , <action>(cprevious)
  
  repeat buf n <action>(bnext)
  repeat buf p <action>(bprevious)
  repeat buf . <action>(bnext)
  repeat buf , <action>(bprevious)
  
  " Emacs C-x z: after repeat (SPC x z or '), bare z keeps repeating
  repeat replay z repeat
  
  " ============================================================================
  " Ace resize — the keys inside the SPC w r session
  " ----------------------------------------------------------------------------
  " SPC w r opens a resize session that stays open until ESC, so one press can
  " nudge the layout many times. Rebind any key here, or map one to `ignore`.
  " ============================================================================
  
  resizemap l <action>(vertical resize +4)
  resizemap h <action>(vertical resize -4)
  resizemap k <action>(resize +2)
  resizemap j <action>(resize -2)
  resizemap = <action>(wincmd =)
  resizemap m <action>(only)
  
  " ============================================================================
  " The stock-Emacs chord layer — outside INSERT only
  " ----------------------------------------------------------------------------
  " Every chord here is a real Emacs key, bound to the meow command that IS the
  " Emacs one. They fire in NORMAL and MOTION, never in INSERT, so Vim keeps
  " C-d / C-k / C-w / C-y while you type. Motions extend a live selection.
  " Any of three spellings works: the Emacs one (C-f, M-<), the host one
  " (control F, alt shift COMMA), or Vim's own (<C-f>, <M-lt>).
  " An unbound chord stays Vim's; to hand a bound one back, map it to `ignore`.
  " ============================================================================
  
  " point motions (C-f C-b C-n C-p C-a C-e, M-f M-b M-a M-e)
  cmap C-f forward-char
  cmap C-b backward-char
  cmap C-n next-line
  cmap C-p previous-line
  cmap C-a move-beginning-of-line
  cmap C-e move-end-of-line
  cmap M-f forward-word
  cmap M-b backward-word
  cmap M-a backward-sentence
  cmap M-e forward-sentence
  
  " buffer + paragraph (M-< M-> M-{ M-})
  cmap M-< beginning-of-buffer
  cmap M-> end-of-buffer
  cmap M-{ backward-paragraph
  cmap M-} forward-paragraph
  
  " case + kill (M-u M-l M-c M-d)
  cmap M-u upcase-word
  cmap M-l downcase-word
  cmap M-c capitalize-word
  cmap M-d kill-word
  
  " stock-Emacs edit chords. Each maps onto the meow command that IS the Emacs
  " one (meow-semantics.md): meow-kill's no-selection fallback is meow-C-k, so
  " C-k kills the line and C-w the region through the same command; meow-save is
  " kill-ring-save; meow-cancel-selection is keyboard-quit; meow-delete is
  " delete-forward-char.
  cmap C-/ meow-undo
  cmap C-_ meow-undo
  cmap C-d meow-delete
  cmap C-k meow-kill
  cmap C-w meow-kill
  cmap M-w meow-save
  cmap C-y meow-yank
  cmap C-g meow-cancel-selection
  
  " C-l recenter-top-bottom: Vim has no argument-free recenter, so this is a core
  " command with Emacs' recenter-positions cycle (center -> top -> bottom,
  " restarting whenever the previous command differs). The adapter runs Vim's own
  " zz / zt / zb for the three positions.
  cmap C-l recenter-top-bottom
  
  " C-v scroll-up-command / M-v scroll-down-command: real Emacs page motions —
  " they move the caret forward/backward by one screenful (minus a 2-line
  " overlap) rather than only scrolling the viewport, and extend an active
  " selection instead of replacing it, like every other point motion here.
  cmap C-v scroll-up-command
  cmap M-v scroll-down-command
  
  " stock-Emacs whitespace and line chords. M-^ is meow-join + kill: killing the
  " join selection IS delete-indentation, so it needs no command of its own.
  cmap M-m back-to-indentation
  cmap C-o open-line
  cmap M-\ delete-horizontal-space
  cmap M-SPC just-one-space
  cmap M-^ ms
  
  " Tranche 2, ported from ideameow: no core isearch command exists, so C-s/
  " C-r are host action chords, like C-l before it went core. Vim's own
  " forward-search (/) and backward-search (?) prompts are the exact native
  " analogs of Emacs' isearch-forward/isearch-backward, and `call feedkeys('/')`
  " is the same idiom the bundled rc already uses at SPC s s / SPC m x; M-;
  " reuses the module command the keypad's SPC w w already dispatches. The
  " other four siblings retarget M-; at a native toggle-line-comment action
  " (NetBeans/DBeaver/VS Code/Notepad++ all ship one); vanilla Vim has none —
  " building one from &commentstring would be new host-side infra, not a
  " verified action id, so it stays declined here, not guessed, unlike the
  " hosts that have a real one. C-; (ace-click) is infeasible for a TUI (no
  " clickable chrome to enumerate) — declined, not guessed, same as neomeow.
  " M-y (PasteMultiple / clipboard history) has no yank-pop/kill-ring-browsing
  " equivalent here either — also declined.
  cmap C-s <action>(call feedkeys('/'))
  cmap C-r <action>(call feedkeys('?'))
  cmap M-; <action>(VimeowAceWindow)
END
