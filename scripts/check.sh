#!/usr/bin/env bash
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

vim_bin="${VIMEOW_VIM:-vim}"
if ! command -v "$vim_bin" >/dev/null 2>&1; then
  echo "vimeow: no vim on PATH (set VIMEOW_VIM)" >&2
  exit 1
fi

echo "==> $("$vim_bin" --version | head -1)"
for feature in vim9script textprop popupwin; do
  if ! "$vim_bin" --version | grep -q "+$feature"; then
    echo "vimeow: this vim lacks +$feature" >&2
    exit 1
  fi
done
echo "==> +vim9script +textprop +popupwin"

echo "==> .vimeowrc in sync with the bundled copy"
"$here/scripts/gen_default_rc.sh" --check

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

echo "==> the BDD suite (test/run.vim)"
set +e
VIMEOW_TEST_OUT="$out" "$vim_bin" -N -u NONE --not-a-term \
  --cmd "set rtp^=$here" -S test/run.vim </dev/null >/dev/null 2>&1
status=$?
set -e
cat "$out"
[ "$status" -eq 0 ] || exit "$status"

echo "==> the adapter smoke test (test/smoke.vim)"
set +e
VIMEOW_TEST_OUT="$out" "$vim_bin" -N -u NONE --not-a-term \
  --cmd "set rtp^=$here" -S test/smoke.vim </dev/null >/dev/null 2>&1
status=$?
set -e
cat "$out"
exit "$status"
