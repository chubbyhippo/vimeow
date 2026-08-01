# vimeow

Emacs + [meow](https://github.com/meow-edit/meow) modal editing for Vim 9,
written in Vim9 script. Selection first, then act — plus the `SPC` keypad that
stands in for Emacs' prefix keymaps, the stock-Emacs chord layer, avy jumps,
grab/beacon multiple cursors, and `ace-window`.

No plugin manager, no dependencies, no compilation: it installs through Vim's
own built-in package mechanism.

## Requirements

Vim 9.0 or newer built with `+vim9script`, `+textprop` and `+popupwin`.
`vim --version | grep -o '+vim9script\|+textprop\|+popupwin'` should print all
three. A system clipboard (`+clipboard`) is used when present and silently
skipped when not.

## Install

```sh
git clone https://github.com/chubbyhippo/vimeow
cd vimeow && ./setup.sh
```

`setup.sh` runs the suite, then symlinks the repo into
`~/.vim/pack/vimeow/start/vimeow`, which Vim sources at startup. `--copy`
copies instead of symlinking, `--check-only` just runs the gates,
`--uninstall` removes it. Or do it by hand:

```sh
mkdir -p ~/.vim/pack/vimeow/start
ln -s "$PWD" ~/.vim/pack/vimeow/start/vimeow
```

Verify:

```sh
vim -c 'echo exists(":VimeowReloadRc") ? "loaded" : "NOT loaded"' -c q
```

Then open a file and press `SPC ?`.

## The layout

Press `SPC ?` for the cheatsheet in Vim; `SPC /` then a key describes what that
keypad entry runs. The short version:

| | |
|---|---|
| `h j k l` | move (cancels the selection) |
| `H J K L` | extend the char selection |
| `w` / `W` | mark word / symbol |
| `e` / `b` | next word end / back word |
| `x` | line (press again to extend) |
| `f` / `t` | find / till a char |
| `o` / `O` | enclosing block / to its end |
| `,` / `.` | inner / bounds of a thing |
| `[` / `]` | to a thing's beginning / end |
| `1`-`9`, `0` | expand the selection by N units; with no selection, a count |
| `i` `a` | insert at the selection's start / end |
| `c` `s` `d` `y` `p` `r` | change, kill, delete, save, yank, replace |
| `u` | undo |
| `v` `n` | visit (regexp) / search next |
| `G` `R` `Y` `z` | grab, swap grab, sync grab, pop |
| `S` | avy — type a few chars, then a home-row label |
| `SPC` | the keypad (`SPC x` = `C-x`, `SPC c` = `C-c`, `SPC m` = `M-`) |

The Emacs chords work outside INSERT: `C-f/b/n/p/a/e`, `M-f/b/a/e`, `M-</>`,
`M-{/}`, `M-u/l/c`, `M-d`, `C-/`, `C-d/k/w/y`, `M-w`, `C-g`, `C-l`, `C-o`,
`M-m`, `M-\`, `M-SPC`, `M-^` — 32 in all, and every one is an rc line you can
rebind or hand back to Vim.

## Configuring it

The whole keymap is data, not code: the bundled [`.vimeowrc`](.vimeowrc) is the
single source of truth, and there is no key anywhere in the Vim9 sources. Copy
what you want to change into `~/.vimeowrc`; your file overrides the defaults
entry by entry, so you only list the differences.

`SPC c m` opens yours (seeding it the first time), `SPC c M` reloads it without
restarting Vim.

```vim
" ~/.vimeowrc
nmap S avy-goto-line              " rebind a NORMAL key
map <leader>ff <action>(browse edit)   " a keypad entry -> an ex command
desc <leader>f files              " its which-key label
cmap C-f ignore                   " hand Ctrl-F back to Vim
resizemap L <action>(vertical resize +8)
set nowhich-key
set grab-color=#cde8cd
repeat qf n <action>(cnext)        " tap-to-continue, like Emacs repeat-mode
```

Full syntax is documented at the top of the bundled `.vimeowrc`.

Statusline: `vimeow#Statusline()` returns `MEOW NORMAL` and friends, or read
`b:vimeow_mode` yourself.

```vim
set statusline=%f\ %{vimeow#Statusline()}
```

## Commands

| Command | |
|---|---|
| `:Vimeow` | attach meow to the current buffer by hand |
| `:VimeowEditRc` / `:VimeowReloadRc` | open / reload `~/.vimeowrc` |
| `:VimeowAceWindow` / `:VimeowAceSwapWindow` | label the windows, jump / swap |
| `:VimeowAceResize` | a resize session that stays open until ESC |
| `:VimeowWindmove{Left,Right,Up,Down}` | Emacs windmove, with its message verbatim |
| `:VimeowWindmoveSwap{...}` | swap the two windows' buffers |

## Scope

vimeow targets what Emacs + meow can do **in a terminal**. Everything above
works in a TTY. Vim has no LSP, so the slots Emacs fills with xref/flymake map
to Vim's own equivalents — tags, `:make`, `:vimgrep` and the quickfix list.

`ace-click` (hint badges over clickable UI) is deliberately absent: a terminal
has no clickable chrome to enumerate, and window panes are `ace-window`'s job.

## Tests

```sh
./scripts/check.sh
```

Checks the Vim features, that the bundled rc and its generated copy agree, then
runs 143 BDD specs headless and a 34-check smoke test that drives a real Vim —
real buffers, windows, text properties and keymaps. `scripts/gen_default_rc.sh`
regenerates the embedded rc after editing `.vimeowrc` (`--check` verifies).

## Layout

```
.vimeowrc                     the bundled keymap — the source of truth
autoload/vimeow.vim           windmove, ace-window/swap/resize, rc, statusline
autoload/vimeow/adapter.vim   EditorPort + ClipboardPort, key and chord routing
autoload/vimeow/ui.vim        UiPort: text properties, popups, which-key
autoload/vimeow/defaultrc.vim generated from .vimeowrc
autoload/vimeow/core/         the shared meow core, host-independent
plugin/vimeow.vim             entry point: commands and autocommands
test/                         the BDD suite, the smoke test and the runner
```

`core/` talks to Vim only through the `EditorPort`, `ClipboardPort` and `UiPort`
interfaces in `core/port.vim`, so the editing semantics are testable against a
fake editor with no Vim buffer in sight.

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE).
