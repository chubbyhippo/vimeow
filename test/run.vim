vim9script
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
# (see LICENSE for the full GPL-3.0-or-later text)

import './helpers.vim' as H

var root = expand('<sfile>:p:h')
var specs = sort(glob(root .. '/*_spec.vim', false, true))
var lines: list<string> = []
var total = 0
var failed = 0

for spec in specs
  var beforePass = H.passed
  var beforeFail = len(H.failures)
  execute 'source ' .. fnameescape(spec)
  var p = H.passed - beforePass
  var f = len(H.failures) - beforeFail
  total += p + f
  failed += f
  add(lines, printf('%-24s %3d passed %3d failed  %s',
      fnamemodify(spec, ':t:r'), p, f, f == 0 ? 'ok' : 'FAIL'))
endfor

for failure in H.failures
  add(lines, '  ✗ ' .. failure)
endfor
add(lines, printf('total: %d passed, %d failed', total - failed, failed))

writefile(lines, expand('$VIMEOW_TEST_OUT'))
execute 'cquit ' .. (failed == 0 ? 0 : 1)
