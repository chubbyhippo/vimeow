# vimeow

Emacs + [meow](https://github.com/meow-edit/meow) modal editing for Vim 9,
written in Vim9 script. Select first, then act.

| | |
|---|---|
| Keypad | `SPC`, standing in for Emacs' prefix keymaps |
| Chords | the stock-Emacs chord layer, 32 of them |
| Jumps | avy |
| Multiple cursors | grab / beacon |
| Windows | `ace-window` |
| Dependencies | none — no plugin manager, no compilation |
| Install mechanism | Vim's own built-in package mechanism |

## Requirements

| Item | Value |
|---|---|
| Vim | 9.0 or newer |
| Features | `+vim9script`, `+textprop`, `+popupwin` |
| Check | `vim --version \| grep -o '+vim9script\|+textprop\|+popupwin'` should print all three |
| `+clipboard` | used when present, silently skipped when not |

## Install

```sh
git clone https://github.com/chubbyhippo/vimeow
cd vimeow && ./setup.sh
```

`setup.sh` runs the suite, then symlinks the repo into
`~/.vim/pack/vimeow/start/vimeow`, which Vim sources at startup.

| Flag | Effect |
|---|---|
| `--copy` | copy instead of symlinking |
| `--check-only` | just run the gates |
| `--uninstall` | remove it |

By hand:

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

`SPC ?` is the cheatsheet in Vim; `SPC /` then a key describes what that keypad
entry runs.

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

### Emacs chords

Active outside INSERT; every one is an rc line you can rebind or hand back to
Vim.

| Group | Chords |
|---|---|
| Point motion | `C-f/b/n/p/a/e`, `M-f/b/a/e` |
| Buffer, paragraph | `M-<`, `M->`, `M-{`, `M-}` |
| Case, word kill | `M-u/l/c`, `M-d` |
| Edit | `C-/`, `C-d/k/w/y`, `M-w`, `C-g`, `C-l`, `C-o` |
| Whitespace, join | `M-m`, `M-\`, `M-SPC`, `M-^` |

## Configuring it

The whole keymap is data, not code: no key lives anywhere in the Vim9 sources.

| Layer | What |
|---|---|
| Bundled [`.vimeowrc`](.vimeowrc) | the single source of truth; full syntax documented at its top |
| `~/.vimeowrc` | your overrides, entry by entry — list only the differences |
| `SPC c m` | opens yours, seeding it the first time |
| `SPC c M` | reloads it without restarting Vim |

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

### Statusline

| Source | Gives |
|---|---|
| `vimeow#Statusline()` | `MEOW NORMAL` and friends |
| `b:vimeow_mode` | the raw mode |

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

vimeow targets what Emacs + meow can do **in a terminal** — everything above
works in a TTY.

| Emacs feature | Here |
|---|---|
| xref / flymake | Vim's own equivalents — tags, `:make`, `:vimgrep`, the quickfix list |
| `ace-click` | deliberately absent — a terminal has no clickable chrome to enumerate |
| window panes | `ace-window`'s job |

## Tests

```sh
./scripts/check.sh
```

| Stage | What |
|---|---|
| Features | the Vim feature check |
| Sync | the bundled rc and its generated copy agree |
| Suite | 143 BDD specs, headless |
| Smoke | 34 checks driving a real Vim — real buffers, windows, text properties, keymaps |
| `scripts/gen_default_rc.sh` | regenerates the embedded rc after editing `.vimeowrc` (`--check` verifies) |

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

`core/` reaches Vim only through the `EditorPort`, `ClipboardPort` and `UiPort`
interfaces in `core/port.vim`.

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE).
