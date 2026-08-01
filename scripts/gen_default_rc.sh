#!/usr/bin/env bash
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Regenerate autoload/vimeow/defaultrc.vim from .vimeowrc so the installed
# plugin reads no file at runtime. --check verifies they are in sync.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$here/.vimeowrc"
dst="$here/autoload/vimeow/defaultrc.vim"

generate() {
  cat <<'HEADER'
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
HEADER
  # `=<<` heredocs take the lines verbatim; a line starting with END would end
  # it early, and trim strips the common indent, so indent every line by two.
  sed 's/^/  /' "$src"
  printf 'END\n'
}

if [ "${1:-}" = "--check" ]; then
  if diff -q <(generate) "$dst" >/dev/null 2>&1; then
    echo "defaultrc.vim is in sync with .vimeowrc"
    exit 0
  fi
  echo "defaultrc.vim is STALE — run scripts/gen_default_rc.sh" >&2
  exit 1
fi

generate > "$dst"
echo "regenerated $dst"
