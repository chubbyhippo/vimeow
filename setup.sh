#!/usr/bin/env sh
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Install vimeow through Vim's own built-in package manager: a symlink (or copy)
# into ~/.vim/pack/vimeow/start/vimeow, which Vim sources at startup with no
# plugin manager involved.
set -eu

usage() {
  cat <<'USAGE'
usage: ./setup.sh [--check-only] [--copy] [--uninstall] [-h]

  (no flags)     run the suite, then install into the Vim package directory
  --check-only   run the suite and the gates, install nothing
  --copy         copy instead of symlinking (for a machine that syncs ~/.vim)
  --uninstall    remove the installed package directory
  -h, --help     this message

Honours VIMEOW_VIM (default: vim) and VIMEOW_PACK
(default: $HOME/.vim/pack/vimeow/start).
USAGE
}

here=$(cd "$(dirname "$0")" && pwd)
vim_bin=${VIMEOW_VIM:-vim}
pack=${VIMEOW_PACK:-$HOME/.vim/pack/vimeow/start}
dest="$pack/vimeow"

mode=install
link=symlink
for arg in "$@"; do
  case "$arg" in
    --check-only) mode=check ;;
    --copy) link=copy ;;
    --uninstall) mode=uninstall ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$mode" = uninstall ]; then
  rm -rf "$dest"
  echo "vimeow: removed $dest"
  exit 0
fi

"$here/scripts/check.sh"

if [ "$mode" = check ]; then
  echo "vimeow: checks only, nothing installed"
  exit 0
fi

mkdir -p "$pack"
rm -rf "$dest"
if [ "$link" = symlink ]; then
  ln -s "$here" "$dest"
  echo "vimeow: symlinked $dest -> $here"
else
  mkdir -p "$dest"
  for item in autoload plugin .vimeowrc LICENSE README.md; do
    cp -R "$here/$item" "$dest/"
  done
  echo "vimeow: copied into $dest"
fi

cat <<EOF

Installed. Vim sources it at startup — no plugin manager needed.
Verify with:

  $vim_bin -c 'echo exists(":VimeowReloadRc") ? "vimeow loaded" : "NOT loaded"' -c q

Then open a file and press SPC ? for the cheatsheet.
Your own keymap goes in ~/.vimeowrc (SPC c m opens it, SPC c M reloads).
EOF
